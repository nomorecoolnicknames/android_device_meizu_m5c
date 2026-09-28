# Патчи к repo-управляемым проектам (страховка от repo sync)

Эти проекты живут ВНЕ этого репозитория и управляются `repo`. Правки в них
не закоммичены в их собственные git-истории, поэтому любой `repo sync` или
`git checkout` в них сотрёт работу безвозвратно: в образе лежит бинарь, а не
исходник, восстановить из него нельзя.

| патч | проект | база, к которой применяется |
|---|---|---|
| vendor_mediatek_FULL.patch | vendor/mediatek | 9dde276 "libril: per-channel serialization for the vendor RIL, ported with four fits" |
| vendor_meizu_m5c_FULL.patch | vendor/meizu/m5c | 0adcdd8 "m5c: не ставить вендорный hwcomposer - он затирал forge_hwc и валил загрузку" |

## Что внутри

vendor_mediatek_FULL.patch — 7 файлов:
Android.mk, include/telephony/ril.h,
ril/libril/{Android.mk, mtk_ril_unsol_commands.h, ril.cpp, ril_service.cpp, ril_service.h}.
Содержит три правки полосы SIM, без которых связь не работает:
1. iccIOForApp: путь MF передаётся как NULL, а не пустой строкой — иначе
   EF_ICCID не читается и подписка не создаётся;
2. RIL_InitialAttachApn без roamingProtocol для m5c (макрос
   MTK_RIL_IAA_NO_ROAMING_PROTOCOL из ril/libril/Android.mk по TARGET_DEVICE) —
   иначе rild падает в strlen через секунду после регистрации;
3. dataCallListChangedInd принимает пустой список — иначе фреймворк не узнаёт
   о разрыве PDP-контекста и не пробует заново.
Плюс более ранние правки полосы m681, которые в этом же файле.

vendor_meizu_m5c_FULL.patch — Android.mk (prebuilt-модули librilmtk/mtk-ril)
и m5c-vendor-blobs.mk (снятые копии тех же библиотек в system/lib*).

## Применение

    cd vendor/mediatek && git apply /path/to/vendor_mediatek_FULL.patch
    cd vendor/meizu/m5c && git apply /path/to/vendor_meizu_m5c_FULL.patch

Если база сдвинулась, применять с `git apply -3` и разбирать конфликты.

Снято 2026-09-03 полосой SIM. Копия этих же файлов лежит в
android_device_meizu_m5c (los16/patches/), но тот репозиторий на другой машине
и опережает origin на 368 коммитов — эта копия рядом с деревом, которое она
страхует.
