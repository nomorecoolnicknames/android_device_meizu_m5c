# M5C SIM READY lane — почему фреймворк держал SIM в NOT_READY

Дата: 2026-08-27. Капча: `captures/20260827-sim-notready/radio_boot.log` (11383 строки, чистая загрузка, Beeline в слоте 1).

## Улики (FACT)

1. Модем карту видит и зарегистрирован: `+CPIN: READY`, `+CRSM: 144,0,"…USIM AID…"`,
   `gsm.operator.numeric=25099`, `+ECSQ: 13,48` (лог, стр. ~5200–5800).
2. Все три запроса `> GET_SIM_STATUS` ([3666] SUB0, [3667] SUB1, [3708] SUB0)
   уходят в rild, обработчик исполняется до конца и **отправляет ответ**:
   `RequestComplete, RIL_SOCKET_1` + `Send Response to RIL_SOCKET_1`
   (стр. 5799–5800 для [3666], 15:29:38.435; стр. ~5330 для [3667]).
3. При этом ни одного `RILJ: [NNNN]< GET_SIM_STATUS` в логе нет — ответ гибнет
   уже **внутри процесса phone**, после чтения из сокета.
4. Дымящийся ствол — 6 блоков (стр. 7778+, 15:29:39.501…39.923):
   ```
   E UiccController: Error getting ICC status. RIL_REQUEST_GET_ICC_STATUS should never return an error
   E UiccController: java.lang.IllegalArgumentException: val.length > 91
   E UiccController:   at android.os.SystemProperties.set(SystemProperties.java:127)
   E UiccController:   at com.android.internal.telephony.MtkEccList.updateEmergencyNumbersProperty(MtkEccList.java:365)
   E UiccController:   at com.android.internal.telephony.MT6735.refreshEmergencyList(MT6735.java:356)
   E UiccController:   at com.android.internal.telephony.MT6735.processSolicited(MT6735.java:413)
   ```
5. Механизм (по исходникам `ril/telephony/.../MT6735.java`, `MtkEccList.java`):
   `MT6735.processSolicited()` ПЕРЕД штатной обработкой ответа GET_SIM_STATUS
   вызывает `refreshEmergencyList()` → `MtkEccList.updateEmergencyNumbersProperty()`
   → `SystemProperties.set("ril.ecclist", <merged>)`. Значение property ограничено
   PROP_VALUE_MAX-1 = 91 символ. Слитый список = ECC с SIM (`ril.ecclist`, rild
   пишет туда "112,911") + **весь** `/system/etc/ecc_list.xml` (~100 записей,
   парсер игнорирует CountryISO). Строка на сотни символов → set() кидает
   IllegalArgumentException → catch(Throwable) в processSolicited молча
   пересылает исключение как результат запроса и НЕ доводит парсинг card status.
   UiccController видит exception → return → UiccCard не создаётся →
   IccCardProxy навсегда NOT_READY (оба слота, поэтому слот 2 не показывает
   даже ABSENT).
6. `/system/etc/ecc_list.xml` на устройстве == `configs/ecc_list.xml` в дереве
   (md5 0bc1d61c8b8ed4106c5cbd50d9c3526b, снято живьём).
7. Живой эксперимент: урезал ecc_list.xml на устройстве до 2 записей (бэкап:
   `/data/local/tmp/ecc_list.xml.orig`), перезапустил com.android.phone —
   результат см. «Вердикт эксперимента» ниже.

## Гипотезы и вердикты

- **ПОДТВЕРЖДЕНО (FACT)**: исключение `val.length > 91` в
  `MtkEccList.updateEmergencyNumbersProperty()`, вызванное из
  `MT6735.processSolicited()`, съедает каждый ответ GET_SIM_STATUS.
  Стек-трейс в логе, 6 из 6 ответов.
- **REJECTED — ABI RIL_CardStatus_v6 блоба mtkrild против LOS**: ответы других
  запросов (BASEBAND_VERSION, GET_RADIO_CAPABILITY, QUERY_NETWORK_SELECTION_MODE)
  маршалятся и доходят; ответ GET_SIM_STATUS доходит до Java (стек-трейс п.4
  срабатывает в processSolicited того же парсel'а) — маршаллинг жив.
- **REJECTED — зависание AT-обмена (CLCK/EFUN)**: поток 802 для [3666] прошёл
  всю цепочку CPIN?→ETESTSIM→CRSM(EF_DIR)→CLCK("SC")→ESIMAPP→завершение за
  120 мс (15:29:38.316…38.435); «нет ответа на CLCK» не подтвердилось —
  `response received` через 17 мс (38.404→38.421), счётчики
  `pin1:3, pin2:3, puk1:10, puk2:10` распарсены.
- **REJECTED — радио остаётся RADIO_OFF / CFUN не шлётся**: MTK шлёт EFUN вместо
  CFUN; `AT+EFUN=1` (38.598) и `AT+EFUN=3` (38.925) ушли, `setRadioState → 10`
  (RADIO_ON) для обоих SUB. Шторм RADIO_NOT_AVAILABLE — только до включения
  радио. `+CME ERROR: 10` на RIL_CMD2/URC2 — второй слот без карты, норма.
- **НЕ БЛОКЕР (INFERENCE)**: `AT+ESIMAPP=0,0` → `+CME ERROR: 100` →
  `queryIccApplicationChannel Error` → `requestOpenIccApplication Fail` — это
  ISIM/IMS-ветка; ответ всё равно ушёл с payload (иначе гейт
  `error==0 || dataAvail>0` не пустил бы в refreshEmergencyList и мы бы
  увидели `[3666]< …error:` из super.processSolicited). Вернуться к ней,
  только если понадобится IMS.
- **REJECTED — SELinux‑денай**: механизм найден в Java, стек полный; отдельный
  поиск avc не потребовался (property `ril.*` для uid radio разрешён — set
  упал по длине, а не по правам).

## Что сделано

1. `ril/telephony/.../MtkEccList.java`: новый `setEccListProperty()` —
   обрезка слитого списка по границе номера до 91 символа + try/catch вокруг
   `SystemProperties.set` (лечит и `ril.ecclist`, и `ril.ecclist1`).
   Для Java-набора номера ничего не теряется: `isEmergencyNumberExt()` смотрит
   полный in-memory `mCustomizedEccList`, а не property.
2. `ril/telephony/.../MT6735.java`: `refreshEmergencyList()` обёрнут в
   try/catch(Throwable) — хозработы по ECC-списку больше никогда не могут
   убить solicited-ответ.
3. Живой эксперимент на устройстве (см. п.7 улик) — вердикт ниже.

## Вердикт эксперимента

**ПОДТВЕРЖДЕНО ЖИВЬЁМ, 15:43.** После урезания ecc_list.xml и рестарта
com.android.phone (pid 3659), без единой правки бинарей:

```
gsm.sim.state = READY,ABSENT
[3748]< GET_SIM_STATUS IccCardState {CARDSTATE_PRESENT,…APPTYPE_USIM,APPSTATE_READY,pin1=PINSTATE_DISABLED…} [SUB0]
IccCardProxy: setExternalState: set mPhoneId=0 mExternalState=READY
IccCardProxy: setExternalState: set mPhoneId=1 mExternalState=ABSENT
mServiceState=0 … voice home data home beeline beeline 25099 … LTE LTE
```

Новых `val.length > 91` нет (6 старых — от прежнего pid 1512). Слот 2 стал
корректным ABSENT — раньше и он висел в NOT_READY, что дополнительно
подтверждает: гибли ВСЕ ответы GET_SIM_STATUS, а не статус конкретной карты.
Телефон зарегистрирован в LTE beeline, voice+data home.

## Что осталось

- **Пересобрать ROM** (телефония): классы из `BOARD_RIL_CLASS :=
  …/device/meizu/m5c/ril` компилируются в `telephony-common.jar`
  (frameworks/opt/telephony) — нужен пересбор system-образа (boot.img не
  причём). После пересборки полный ecc_list.xml можно вернуть — фикс делает
  его длину безвредной.
- На устройстве сейчас живёт урезанный `/system/etc/ecc_list.xml` (2 записи);
  оригинал в `/data/local/tmp/ecc_list.xml.orig`. Штатная сборка вернёт полный.
- Вторичный дефект в `MT6735.processSolicited` catch-блока: запрос не
  снимается с `mRequestList`, а caller делает `rr.release()` → двойная
  доставка ошибки (6 событий на 3 запроса в логе). После фикса путь мёртвый,
  но при случае стоит переписать catch на findAndRemoveRequestFromList.
