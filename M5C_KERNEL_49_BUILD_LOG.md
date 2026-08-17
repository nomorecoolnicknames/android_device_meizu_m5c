# M5c — журнал сборки ядра 4.9 arm64 (Phase P0+)

Исполнитель: субагент k49-build. План: `M5C_KERNEL_49_PORT_PLAN.md` (v2).
Авторитет по железу: `M5C_CHIP_MAP.md`. Формат: FACT / INFERENCE /
HYPOTHESIS / REJECTED по `/srv/forge/android/CLAUDE.md`.

## 2026-08-17 (P19 РЕЗУЛЬТАТ + P21) Счётчик СТОИТ; путь прерывания исправен

FACT (team-lead, p19, od count=1024): 57 CNTPCT_EL0 = 0 (физсчётчик СТОИТ);
58 CNTP_CTL_EL0 = 0x1 (ENABLE=1, IMASK=0, ISTATUS=0); 59 CNTP_CVAL=52000;
60 GICD_ISENABLER0 = 0x6000dfff (PPI 29 И 30 размаскированы); 52 jiffies
стартовые; маркеры 44✔ 45✘ 61✘ 62✘. Читается однозначно: таймер включён,
не замаскирован, компаратор заряжен, PPI на дистрибьюторе включены — а
прерывания нет, потому что СЧЁТЧИК НЕ ИДЁТ (CNTPCT=0 и ISTATUS=0
подтверждают друг друга; за 12 мс при 13 МГц прошло бы ~143000 > 52000).

REJECTED вся линия PPI/тиковое устройство — прерывания ни при чём. p20 не
нужен. Живой 3.18 (эталон): clockevent0=arch_sys_timer, /proc/interrupts
30: 11047 arch_timer → на этом железе тикает АРХ-ТАЙМЕР, PPI 30, и счётчик
ИСПРАВЕН (значит дефект софтовый, запуск счётчика).

FACT (team-lead, по исходникам): setup_syscnt() вызывается (лог `fwq sysc
count`), тело идентично 3.18, CPUXGPT_BASE/INDEX/CTL/EN одинаковы,
маппинг ок (cpuxgpt_r.start=0x10200000). Значит код запуска исполняется и
совпадает с рабочим, а счётчик стоит → запись не доходит или отменяется.

FACT (моя поправка по коду): __write_cpuxgpt использует mcusys_smc_write_PHY
(= mt_secure_call MTK_SIP_KERNEL_MCUSYS_WRITE = SMC в ATF), не прямой
writel; под CONFIG_MTK_PSCI. НО MTK_PSCI=y И у 3.18 → 3.18 тоже идёт SMC
и тикает → SMC-путь не сломан, ATF honorit SIP. Значит разница в
моменте/состоянии либо запись не садится по иной причине.

Сделано (P21, коммит `7bc95c2e3`, образ `boot_49_p21.img`, sha256
`656af67609cf28356656b0d55e8e3b84fe39dde64f75f2de0f74889842641c6a`,
System.map-p21): чтение INDEX_CTL_REG обратно тем же SMC-путём — слот 65
до enable, 66 после, 67 в цикле wait_task_inactive; 68 CNTFRQ_EL0, 69
второе CNTPCT. Разрез: 66 EN=0 → запись глотается (смотреть mt_secure_call
ASM/INDEX_BASE_PHY); EN=1 & CNTPCT=0 → включён но не тактируется
(делитель/CNTFRQ); 66 EN=1 & 67 EN=0 → гасится позже (disable_cpuxgpt из
idle/hotplug, cpuidle_v1 собран).

## 2026-08-17 (аддендум team-lead + P20) Кто тиковое устройство: GPT1 или arch timer?

FACT (team-lead, лог p13): apxgpt-фикс поднял НЕ ТОЛЬКО clocksource
(GPT2), но и clockevent GPT1 (`[mtk_gpt] gpt1: cmp=52000, hz=250` —
SPI 184); следом регистрируется arch timer (PPI 29). Какой из двух стал
тиковым — в логе не видно; от этого зависит, улика ли пустой маркер 55.

FACT (мой, по исходнику): рейтинги — GPT clockevent 300, arch timer 450 →
тиковым должен стать arch timer. Но фиксируем рантайм.

Сделано (P20 = P19 + аддендум, коммит `1fe3304ff`, образ
`boot_49_p20.img`, sha256
`74e95e7c66dac9351f0cd4c3889f7036611df43549d12996fc9e1cded56b1084`,
System.map-p20): слот 63 = 8 байт имени tick_cpu_device(0).evtdev
(helper в tick-common.c: "arch_sys" | "mt6580-g"); слот 64 =
GICD_ISENABLER5 (SPI 184 = бит 24). Плюс всё из P19 (CNTPCT/CNTP_CTL/
CNTP_CVAL/GICD0, маркеры 61/62 в arch_timer_starting_cpu).

Матрица: 63=arch_sys → ветка PPI (61/62 → 60 биты29/30 → 58 CTL);
63=gpt → ветка SPI 184 (64 бит 24, дальше GPT1_CON); 57 CNTPCT стоит →
системный счётчик (cpuxgpt/ATF), ниже обоих clockevent'ов.

Также FACT (по коду, отправлен team-lead): gic_cpu_init на boot CPU
пишет 0xffff0000 в GIC_DIST_ENABLE_CLEAR — ВСЕ PPI отключаются на init
(штатно для GIC); PPI 29/30 живут только если enable_percpu_irq
вызван. Поэтому «request_percpu_irq err=0» ничего не гарантирует.

## 2026-08-17 (P18 РЕЗУЛЬТАТ + P19) ДОКАЗАНО: arch-таймер PPI не приходит ни разу

FACT (team-lead, `boot_49_p18.img`, recovery 65 с): скобки 33/38/39/41/42/43/
**44** стоят, **45 НЕ стоит** → вис в `kthread_bind_mask()`. Свидетели:
48 jiffies до bind = 0x…FFFEDB08 (= -300*HZ, старт), 52 внутри цикла
wait_task_inactive = ТО ЖЕ (jiffies не двигаются), 54=1 виток,
**55 (arch_timer_handler_phys) = 0**, **56 (счётчик тиков) = 0**.
ДОКАЗАНО прямым измерением в трёх точках: **таймерное прерывание не
приходит ни разу за загрузку**; ядро висит в первом таймерном сне
(kthread_bind_mask → wait_task_inactive → schedule_hrtimeout).

FACT (team-lead, две поправки к измерению): (1) слот 48 усечён до 32 бит
у ИСТОЧНИКА (writer u64-корректен); (2) CNTVCT читал ВИРТУАЛЬНЫЙ счётчик,
а ядро при arch_timer_uses_ppi=0 работает с ФИЗИЧЕСКИМ — мерить CNTPCT_EL0.
REJECTED (team-lead, чтение кода): «cpuxgpt не собран» — MACH_MT6735M=y,
setup_syscnt() собран, лог cpuxgpt_r.start=0x10200000 без ошибок.
RETRACTED окончательно: полярность PPI 29/30 — косметика (геттер
mt_irq_get_pol_hw печатает «Fail to set» и врёт; mt_gic_set_type уже
настроил тип штатным GIC-путём и вернул 0; err=0 при request_percpu_irq).

Сделано (P19, коммит `6a487c6ff`, образ `boot_49_p19.img`, sha256
`5aef805b2917d26942e2e94d55404a028de2284c1f85e9b5fb4c3c89cdce33f4`,
System.map-p19): физрегистры полной ширины в цикле wait_task_inactive —
57 CNTPCT_EL0, 58 CNTP_CTL_EL0 (ENABLE/IMASK/ISTATUS), 59 CNTP_CVAL_EL0,
60 GICD_ISENABLER0 (PPI 29/30); 52 → get_jiffies_64(); маркеры 61
(arch_timer_starting_cpu вошёл на boot CPU) и 62 (enable_percpu_irq
вызван). `forge_gicd_isenabler0()` добавлен в irq-mt-gic.c. flush→1024.

ВЕДУЩАЯ ГИПОТЕЗА (team-lead): в 4.9 per-cpu enable PPI перенесён в
CPUHP_AP_ARM_ARCH_TIMER_STARTING; если состояние не проехало на boot CPU,
request_percpu_irq вернул err=0, но PPI остался ЗАМАСКИРОВАН. Разрез: 61
пуст = callback не выполнялся; 61/62 есть, 60 без бит 29/30 = дистрибьютор
не размаскировал (баг mt_gic для PPI); 58 ENABLE=0 = компаратор не
запрограммирован. Возможная связь с моей cpuhp-регистрацией gic_starting_cpu
(CPUHP_AP_IRQ_GIC_STARTING) — проверить порядок состояний.

## 2026-08-17 (P16 результат + P18) kthreadd невиновен; подозрение — первый таймерный сон

FACT (team-lead, `boot_49_p16.img`, recovery за 65 с): слоты 33, 38, 39
СТОЯТ; 40, 35, 36 НЕТ. kthread_create_on_node ВЕРНУЛСЯ → kthreadd (PID 2)
исполнялся, поток создан. REJECTED: гипотеза «kthreadd не бегает»
(планировщик в принципе переключает задачи). Вис — между 39 и 40:
set_user_nice → kthread_bind_mask → worker_attach_to_pool →
spin_lock_irq{enter_idle, wake_up_process}.

HYPOTHESIS (главная, team-lead + моё уточнение): kthread_bind_mask →
wait_task_inactive — ПЕРВЫЙ ТАЙМЕРНЫЙ СОН всей загрузки. Уточнение по
дереву: в 4.9 сон — `schedule_hrtimeout(1 tick)` (не jiffies-таймаут), но
hrtimer программирует тот же arch-clockevent. Механика попадания: при
PREEMPT свежий kthread вытесняется между complete() и schedule() →
родитель видит queued → ветка hrtimeout. Если PPI arch-таймера не
стреляет (те самые «Fail to set polarity of interrupt 29/30» из моего
mt-gic ПЕРЕСТАЮТ быть косметикой) — сон вечен и молчалив. Вторая
гипотеза: wake_up_process под spin_lock_irq (пик с вырожденной
топологией).

Сделано (P18, коммит `be52d752c`, образ `boot_49_p18.img`, sha256
`8c39250af0b44876cd30ae20ba143235ddb3d7e61763b4b52a857e0169d5ec68`,
System.map-p18; надмножество p17 — kthreadd-слоты 41–43 внутри):
- скобки 44/45/46 (set_user_nice / kthread_bind_mask /
  worker_attach_to_pool);
- ПОЗИТИВНЫЕ свидетели-значения: 48/49 jiffies+CNTVCT до bind, 50/51
  после; 52/53/54 jiffies/CNTVCT/витки ВНУТРИ цикла wait_task_inactive
  (gated SYSTEM_BOOTING); 55 one-shot в arch_timer_handler_phys (PPI
  выстрелил хоть раз), 56 счётчик тиков загрузки.
Ключевой разрез: 52=замороженные jiffies (старт 0xFFFF…B4B0 = -300*HZ,
HZ=250) + растущий 53 + пустой 55 → «тик не приходит» доказан
ИЗМЕРЕНИЕМ. Тогда цель — clockevent/полярность PPI в портированном
mt-gic или порт ca53_timer из 3.18.

## 2026-08-17 (анализ team-lead + P17) kthreadd под подозрением; init_heavy_tlb невиновен

FACT (team-lead, чтение sched_avg.c:1095+): `init_heavy_tlb` при cid=-1
печатает и идёт дальше — ни ожиданий, ни блокировок; лог показывает
прохождение всех 4 ядер. REJECTED как виновник; конфиг-опыт RQAVG_KS=n —
низкий приоритет.

HYPOTHESIS (team-lead, главная): create_worker → kthread_create_on_node
ставит запрос в очередь kthreadd (PID 2) и блокируется на
wait_for_completion — ПЕРВОЕ место загрузки, где ядру нужен ДРУГОЙ поток.
Если планировщик не даёт PID 2 исполниться (вырожденная топология:
cluster_id=-1 у всех, nr_clusters=1, sched-домейны ещё дефолтные, но
set_sched_topology уже подменён на arm64_topology с NULL-energy) — вечное
молчание без единой печати. Workqueue может быть невиновен вовсе.

Сделано (P17, коммит `cc7d930f7`, образ `boot_49_p17.img`, sha256
`a08198bba9377ed1cc8787ee65836f5c02bf8602d68806f90d7d81eacd9d6c0c`,
System.map-p17, надмножество p16): маркеры 41 (вход в kthreadd = PID 2
исполнялся), 42 (снял запрос из списка), 43 (create_kthread вернулся).
Объединённая бисекция: 38-без-39-без-41 = PID 2 не бегал → планировщик;
41-без-42 = потерянное пробуждение; 42-без-43 = вис в do_fork;
43+39-без-40 = bind/attach/wake.

В очереди (если подтвердится «PID 2 не бегал»): сверка link-order
early_initcall'ов 3.18 до init_workqueues (структурная разница 4.6+:
workqueue_init вызывается из kernel_init_freeable ДО всех initcall'ов);
оговорка — на 3.18 kthreadd тоже исполним до initcalls, так что
«подготовка» может оказаться пустым множеством.

## 2026-08-17 (P15 результат + P16) Вис — внутри workqueue_init(), до первого initcall

FACT (team-lead, `boot_49_p15.img`, recovery за 175 с): две независимые
улики сходятся. Слоты: 21–24 стоят, 25–32 НЕТ (включая 31 «workqueue_init
прошёл»). initcall_debug доехал до ядра (есть в Kernel command line), но в
логе НОЛЬ строк "calling" → ни один initcall не запускался.
ВЫВОД: вис внутри `workqueue_init()` — do_pre_smp_initcalls и
lockup_detector_init выбывают. (workqueue_init как третий кандидат окна
добавил я; он и оказался виновником.)

REJECTED (team-lead, подтвердил подсчётом по логу): его трактовка
асимметрии CPU0/CPU1 — ранний PID0-проход прошёл все 4 ядра, PID1-строка
одиночная из store_cpu_topology(cpu0). Цикл energy-кода ни при чём.

FACT (структура в этом дереве): в 4.9.188 wq_numa_init и создание
unbound/ordered wq живут в workqueue_init_early (прошёл давно); тело
workqueue_init = per-cpu create_worker цикл → unbound-пулы →
wq_watchdog_init. create_worker при провале даёт BUG_ON (печать), тишина
= ОЖИДАНИЕ — главный подозреваемый kthread_create_on_node, вечно ждущий
kthreadd (планировщик не даёт PID 2 исполниться; MTK-хуки пика с нулевыми
capacity — кандидат механизма; ленивый init_heavy_tlb уже дёргался из
sched-хука на 0.0117).

Сделано (P16, коммит `ba8ceb80b`, образ `boot_49_p16.img`, sha256
`a1a399fb3c66c8a4e9a7c19b3047e1bd58304907018d7781da228c6a73e6d888`,
System.map-p16, initcall_debug сохранён): маркеры 33 (вход), 38/39/40
(one-shot трасса первого create_worker: вход / kthread_create_on_node
вернулся / worker разбужен), 35 (per-cpu цикл), 36 (unbound), 31 (выход).
Решающая пара: 38-без-39 = ждём kthreadd → планировщик/пик; 39-без-40 =
bind/attach/wake.

Уточнение по H2-конфигу (team-lead): CONFIG_MTK_SCHED_RQAVG_KS=y И у
рабочего 3.18 (код за опцией разный — init_heavy_tlb есть только в 4.9),
так что опыт «выключить» валиден как «убрать код, которого на рабочем
ядре нет», но НЕ как «привести конфиг к 3.18». UNIFY_POWER/SCHED_TUNE/
ENERGY_AWARE выключены → upower-ветки вне сборки, полноценного EAS нет.

## 2026-08-17 (P13 результат + P15) H1 ОТВЕРГНУТА маркерами; вис в тихом pre-smp окне

FACT (team-lead, `boot_49_p13.img`, возврат в recovery за 65 с = WDT, улики
целы): apxgpt-фикс РАБОТАЕТ — таймстампы настоящие, ядро умирает через
**12 мс** после старта (последняя строка [0.012000]), WDT добивает на ~60 с.
Лог обрывается байт-в-байт там же, где p11. Слоты: 1–18, 20, **21–24**
стоят; **25–30 НЕ стоят** (оба зеркала согласны).

REJECTED: **H1 (подъём вторичных ядер)** — слот 25 (вход в cpu_boot) не
выставлен, в путь secondary мы не входили вовсе; SMC/mtcmos ни при чём.

FACT (бисекция слотами): 22 (после smp_prepare_cpus) есть, 28 (перед
smp_init) нет → вис строго в окне, где ровно три вызова:
`workqueue_init()`, `do_pre_smp_initcalls()`, `lockup_detector_init()`
(проверено по коду; team-lead назвал два — workqueue_init добавлен).

Поправка к «висит в цикле energy-кода» (проверено по исходнику):
PID1-строки "Invalid sched_group_energy for CPU0 / CPU0: update
cpu_capacity" печатает `store_cpu_topology(cpu0)` ИЗНУТРИ
`smp_prepare_cpus` — единственный вызов, не цикл; 22 стоит → она
вернулась. CPU0-строка — последний print перед тихой зоной, H2 остаётся
гипотезой второго порядка.

Сделано (P15, коммит `2334eca85`, образ `boot_49_p15.img`, sha256
`42952abc72e51767d14b22e5ae0e375fc5763b3a01e7db8f38ae66435a5aeea5`):
- cmdline + `initcall_debug` (в p13 его не было — 0 строк "calling";
  рабочее 3.18 грузится с ним) → имя зависшего initcall прямо в логе;
- маркеры 31 (+256: workqueue_init прошёл) и 32 (+264: pre-smp initcalls
  прошли); flush kmark расширен до 512 B. System.map-p15.
Бисекция: 22-без-31 = workqueue_init; 31-без-32 = early_initcall (имя по
"calling" в хвосте); 32-без-28 = lockup_detector_init.

## 2026-08-17 (p12 разбор + WDT deadman + p14)

FACT (team-lead/владелец): p12 висел на бутлого (LK отработал, ядро повисло);
улики УНИЧТОЖЕНЫ — в 0x5f000000 нет DBGC, окно маркеров 0x7f000000 полностью
нулевое. Причина: вис без WDT-сброса прерывается только длинным power =
холодный сброс PMIC = потеря DRAM.

INFERENCE (team-lead, принята с поправкой): сброса по WDT не было → p12 дошёл
до device-initcalls (существенно дальше p11) → maxcpus=1 снял SMP-вис → H1
поддержана косвенно. Поправка моя: механизм «нет сброса» — не только
«драйвер разоружил»: (а) probe переводит WDT в dual/IRQ-режим, IRQ-стадия
не стреляет при замёрзших прерываниях; (б) per-cpu кикеры продолжают кикать
«живую, но застрявшую» систему. Оба закрываются одним решением.

Сделано (коммит `f7eaac260`): CONFIG_MTK_WDT_DIAG_HARD (=y в defconfig) —
probe армит WDT в чистом reset-режиме (как LK, без dual/IRQ), а
mtk_wdt_restart() не кикает никогда. Любой вис → тёплый сброс в пределах
таймаута, DRAM с логом/маркерами жива. Цена: здоровая загрузка тоже
сбрасывается ~30 с — опция diagnostic-only, для adb-образов выключать.
Правило с этого момента: все диагностические образы идут с deadman.

Артефакт `boot_49_p14.img` = p13 + deadman, sha256
`f5bfa2ef82f1fc89ca23cb8272f33cc3a159a6a12fece1e753e13e70f93abcd6`,
System.map-p14. Очередь: сначала результат p13 (вис до initcalls → улики и
так выживут), p14 — если p13 уйдёт в p12-класс.

## 2026-08-17 (P11 лог + P12 + P13) Лог живой; смерть на SMP-участке; скобки 21-30

FACT (team-lead, `boot_49_p11.img`): ЛОГ РАБОТАЕТ — 103 строки, вся загрузка
с `Linux version 4.9.188-m5c+ #21`. Путь фолбэка ram console подтверждён
построчно. Обрыв: последняя строка `[1:swapper/0] CPU0: update cpu_capacity
1024` — PID 1, участок sched/SMP-инициализации; `CPU1: Booted secondary
processor` нет. Обрыв не по переполнению (9248/64064 байт).

FACT (живая сверка team-lead с 3.18 на том же железе):
- `NR_IRQS:64 nr_irqs:64` у 3.18 ИДЕНТИЧНО → REJECTED как расхождение.
- sched_clock: у 3.18 «32 bits at 13MHz» (это mt_gpt: wraps 330382100403ns
  = 2^32/13МГц), таймер — MTK ca53_timer; у 4.9 дженерик arm_arch_timer, а
  sched_clock остался jiffies 250 Hz. Root cause НАЙДЕН в исходнике:
  4.9 `CLOCKSOURCE_OF_DECLARE("mediatek,APXGPT")` vs стоковый DTB
  `apxgpt@10004000 compatible="mediatek,mt6735-apxgpt"` (3.18 матчит его).
  ПЯТЫЙ блокер класса «compatible mismatch» на m5c. Фикс: второй
  OF_DECLARE (коммит `f6e001116`).
- `Fail to set polarity of interrupt 29/30` — только у 4.9 (дженерик лезет
  в MTK sysirq за полярностью PPI); косметика, контекст к таймеру.
- H2-строки (`Invalid sched_group_energy`, `init_heavy_tlb cid=-1`) у 3.18
  отсутствуют, но и кода того в 3.18 нет; конфиг-паритет уже выполнен
  (SCHED_TUNE/ENERGY_AWARE/MTK_UNIFY_POWER выключены, RQAVG=y как у 3.18).
- 3.18 поднимает 4 ядра за 82 мс → железо/PSCI исправны, вопрос в 4.9-коде.

FACT (`boot_49_p12.img` = ядро p11 + maxcpus=1): поведение КАЧЕСТВЕННО
изменилось — за 200+ с ни recovery (нет WDT-возврата, который LK делает при
wdt_by_pass_pwk), ни USB-устройства на шине вообще. INFERENCE: сброса по WDT
не было; ядро либо ушло дальше и висит там, где WDT кикается, либо стоит
без USB-гаджета. Лог снимет владелец при ручном входе в recovery.

INFERENCE (уточнение формулировки, team-lead + моё): «вис на подъёме
вторичных ядер» слишком широко — arm64 __cpu_up при невзлетевшем secondary
печатает "failed to come online" через 5 с и продолжает. Молчание до WDT →
спин под спинлоком в mtcmos-полле ЛИБО развал системы от secondary,
стартовавшего в плохом состоянии.

Сделано (P13, коммиты `f6e001116` + `0f18a0138`, образ `boot_49_p13.img`,
sha256 `5ecd987784e73f1037e6c266c85701d2dd04f9748d8c8090276af18422b7b320`,
System.map-p13): apxgpt-фикс + маркеры 21-30 (скобки smp_prepare_cpus /
smp_init; mt_psci_cpu_prepare 23/24; cpu_boot 25, после psci cpu_on 26,
после mtcmos POWER_ON 27; 30 = вход в secondary_start_kernel — штамп с
самого вторичного ядра). Читать count=256; бисекция: 25-без-26 = SMC в ATF;
26-без-27 = mtcmos-полл; 27-без-30 = secondary не исполняет C; 30-без-29 =
secondary жив, но система разваливается.

Захват p11: `captures/20260817-49-p11/` (лог+бинарь, снял team-lead).

## 2026-08-17 (P10 результат + P11) Вторая развилка sram_log_save; WDT-переоценка

FACT (team-lead, `boot_49_p10.img`): 4.9 ДОКАЗАННО отработало — в окне
0x5f000000 свежие поля (+0x208=0x0d15ab1e, +0x210=указатель
`0xffffff8008da0fe8` — диапазон ядерных VA 4.9; у 3.18 `0xffffffc0…`).
Смерть — по watchdog: `androidboot.bootreason=wdt_by_pass_pwk`,
`boot_reason=4`. Тело лога снова пустое при валидном заголовке.

REJECTED (переоценка, team-lead): «50→90 с = ядро прошло дальше» —
длительность бутлупа задаётся таймаутом WDT от последнего kick, а не
глубиной загрузки. Из трактовок убрать. Зато «висит, а не паникует» —
улика сама по себе.

FACT (root cause #2, team-lead по исходнику): у `sram_log_save` ДВЕ
реализации. При `CONFIG_PSTORE=y` компилируется вариант, который лишь
форвардит в `pstore_bconsole_write()` — а тот no-op до регистрации
ramoops (device-initcall; `fs/pstore/platform.c` проверяет psinfo).
Настоящий DRAM-писатель жил под `#else`. Мой P10-фикс (register_console)
был необходим, но закрыл только первую из двух развилок: консоль честно
звала sram_log_save → в пустоту.

Сделано (P11, коммит `f1d4d19d9`, образ `boot_49_p11.img`): по рецепту
team-lead — DRAM-писатель вынесен в always-compiled
`ram_console_dram_save()` (тело без изменений), оба варианта
`sram_log_save` зовут его (pstore-форвард сохранён — не конфликтуют),
bounds-check в `aee_sram_fiq_log` выведен из-под `#ifndef PSTORE` +
NULL-guard. Раскладка 0x5f000000 и безусловный register_console на месте.

Артефакт: `/srv/forge/android/m5c/kernel-m5c-4.9-lc/boot_49_p11.img`,
sha256 `07f341b5a9063274394d2a66dc2d39b9ab0b88d7f6a392af6945e0f55f6c8d12`,
9459712 B, boot (p7); System.map-p11 рядом. ОТЛИЧИЕ от P10 кроме рецепта:
в defconfig включён fan5405 (Phase A, см. ниже) — charging_hw сменился с
pmic на fan5405; на раннюю загрузку не влияет, при упоре хвоста лога в
battery/charging-init учитывать.

Ожидание: тело = ВСЯ загрузка с первого printk (CON_PRINTBUFFER);
хвост strings = операция, на которой висим до WDT. «head пуст, tail есть»
— отдельный сигнал.

## 2026-08-17 (фоновая подготовка Phase A/B/C, пока P10 ждёт окна)

Всё скомпилировано и закоммичено в `m5c-arm64`; в P0-defconfig НЕ включено
(диагностические образы не меняются), кроме fan5405 (нужен Phase A):

- **LCM-стек** (коммит `93b7d2cd2`): панели `ili9881c_dsi_vdo_dj_hd720`
  (С поправленными на железе стоковыми таблицами из 4137458e) и
  `jd9365_dsi_vdo_holitech_hd720` + bias `lp3101.c` (из committed HEAD,
  in-flight правки НЕ взяты) перенесены в 4.9; заведены в
  `mt65xx_lcm_list` (jd9365 первым, ili9881c вторым — LK передаёт
  `lcm=1-ili9881c…`); в `lcm_drv.h` добавлены compat-typedef'ы
  (4.9-хедер только с тегами структур). Компилируются все объекты;
  warnings идентичны 3.18-базе. jd9365-таблицы пока 3.18-версии (225
  записей) — байт-точные стоковые 227 приложить на верификации Phase B.
- **fan5405** (коммиты `9067aab41`, `58aa21c2d`, `f5f007061`, ВКЛЮЧЁН в
  defconfig): зеркало проверенного 3.18-фикса 2f918464 — compatible
  `mediatek,swithing_charger` в of_match, BUSNUM 3→1, fallback of_find;
  плюс два линк-фикса Q0-пары (fan5405 нигде не определял
  `chargin_hw_init_done`; `chr_control_interface` был с префиксом
  `fan5405_`, который никто не зовёт). Полный Image.gz-dtb линкуется.
- **Тач GT9XXTB_hotknot** (коммит `29e0cbd69`): проверенный 3.18-драйвер
  (с фиксами 2f918464: ориентация 180°, GTP_MAX 720x1280, политика
  «фабричный конфиг панели», header-FW-update off) перенесён; 4.9-правки:
  `rtpm_prio.h` умер — RTPM_PRIO_TPD=4 локально; каталог выведен из-под
  mediatek `-Werror` на два безобидных 3.18-warning'а. Все три объекта
  собираются и линкуются. FocalTech-сосуществование — на этапе defconfig
  Phase C (нативный focaltech_touch в 4.9 есть).

## 2026-08-17 (P9 результат + P10) Найден и закрыт разрыв записи: register_console за #ifndef PSTORE

FACT (team-lead, `boot_49_p9.img`): вехи 18/20 стоят; окно 0x5f000000
содержит корректный заголовок ram console — сиг `DBGC`, поля декодируются
как off_console=0x5c0, sz_console=0xfa40 (=0x10000−0x5c0 ✓) — т.е. наш
фолбэк-init отработал и читатель больше ничего не съедает. Но тело лога —
НУЛИ: ни байта текста. Бутлуп удлинился ~50→90 с (INFERENCE team-lead:
ядро доходит дальше). Вывод: разрыв — в пути записи.

FACT (root cause, одна строка): в Q0-коде `ram_console_init` регистрация
консоли обёрнута `#ifndef CONFIG_PSTORE` — при включённом PSTORE (у нас)
ram console НЕ регистрируется вовсе, Q0 полагается на pstore/ramoops. Но
ramoops начинает писать только с device-initcalls — ядро, умирающее между
console_init и probe ramoops (ровно наше окно), не оставляет НИ строчки.
Заголовок есть (его пишет init), тело пустое. У 3.18 та же конструкция, но
он доживает до ramoops — потому у него pstore полон.

Сделано (P10, коммит `0c9418f99`, образ `boot_49_p10.img`):
`register_console(&ram_console)` — безусловно. Сосуществует с
pstore-консолью; printk с момента console_init ложится в тело ram console
на 0x5f0005c0 (uncached-маппинг remap_lowmem → в DRAM без флаша).

Артефакт: `/srv/forge/android/m5c/kernel-m5c-4.9-lc/boot_49_p10.img`,
sha256 `721dcd2645e3445955426b17df0b5356cbb1f93052f695c3e280c4aee344cbf7`,
9459712 B, boot (p7); DTB сток (md5 внутри проверен); System.map-p10
рядом; маркеры 1–20 на месте.

Чтение после бутлупа: как P9 —
```
dd if=/dev/mem of=/tmp/rc49.bin bs=1024 skip=1556480 count=64
strings -n 6 /tmp/rc49.bin | head -60 ; strings -n 6 /tmp/rc49.bin | tail -60
```
Ожидание: полный printk-лог 4.9 с банером; хвост = точка смерти.
Это НЕ кандидат «дойдёт до adb» — диагностический (умирает в initcalls,
лог покажет где).

## 2026-08-17 (P8 результат + P9) console_init ПРОЙДЕН; лог уносим из-под читателя

FACT (team-lead, `boot_49_p8.img`): вехи 18 И 20 стоят — ram_console-фикс
работает, console_init завершается полностью. Бутлуп ~50 с (т.е. умирает
где-то в do_initcalls/позже). 4.9-текста нигде нет: last_kmsg/pstore — снова
3.18-сессия; сырое окно 0x43f00000 при чтении начинается с `DBGC` —
структура ram console ТЕКУЩЕГО (recovery) ядра.

INFERENCE (team-lead, принято): читатель уничтожает улику. Recovery — наше
же 3.18-ядро, оно реинициализирует 0x43f00000/0x43f10000 при своей загрузке,
до всякого dd. Разделить «4.9 не писал» от «писал, но затёрто» через этот
канал нельзя. Дополнительно: recovery'шный last_kmsg с PSTORE_CONSOLE
показывает pstore-контент, а не тело ram console — а pstore у 4.9 пишется
только с device-initcalls (ramoops probe), до которых мы, видимо, не дожили.

Сделано (P9, коммит `e9bfa81da`, образ `boot_49_p9.img`): debug-раскладка —
фолбэк ram console теперь указывает на **0x5f000000/0x10000** (pstore
0x5f010000/0xe0000) — адрес из контрольно-валидированных выживших
(0x5f000000 пробу пережил; 0x7f/0xb0 заняты маркерами). Recovery это окно не
трогает → лог 4.9 доживёт до dd. Коммент в коде фиксирует: после появления
adb вернуть стоковые окна, чтобы last_kmsg работал штатно.

Артефакт: `/srv/forge/android/m5c/kernel-m5c-4.9-lc/boot_49_p9.img`, sha256
`d829e46a16d6a48b61a728fc267cf0ea61b9fd3e70c6ab95dba74d28506c3700`,
9459712 B, boot (p7); DTB сток (md5 внутри проверен); System.map-p9 рядом.
Маркеры 1–20 на месте.

Чтение после бутлупа (из recovery):
```
dd if=/dev/mem of=/tmp/rc49.bin bs=1 skip=1593835520 count=65536   # 0x5f000000
strings /tmp/rc49.bin | head -100    # ждём полный 4.9 boot-лог
dd if=/dev/mem of=/tmp/fD.bin bs=1 skip=2130706432 count=176 ; od -x /tmp/fD.bin   # маркеры как раньше
```
В тексте грепать: `4.9.188`, `m5c+`, `debug layout @0x5f000000`, последние
строки перед смертью → это и есть точка следующего фикса.
Если окно 0x5f000000 ПУСТО при вехах 18/20 → flush пути записи ram console
(console write → DRAM) не доходит — тогда чинить путь записи, а не читатель.

## 2026-08-17 (P7 результат + P8) Виновник — ram_console_early_init (BUG без LK-контракта)

FACT (team-lead, `boot_49_p7.img`): слот 19 = `0xffffff8008bd7bf8` =
**`ram_console_early_init`**; веха 20 не встала. REJECTED: гипотеза про
`mtk_uart_console_init` (адрес …bd54bc в слоте не оказался) — UART-console
прошёл нормально, повис именно ram console. Ирония: висла ровно та
подсистема, что дала бы нам текст.

FACT (root cause, source diff 4.9 vs 3.18): Q0-шный `ram_console_early_init`
ТРЕБУЕТ от LK контракт `chosen/ram_console` + `memory_info`
(magic1/magic2, dram/pstore/mrdump-поля) и на ЛЮБОЕ отклонение зовёт
`ram_console_fatal()` → **BUG()** — тихая паника до консоли → WDT-бутлуп.
Стоковый LK 2017 года этого контракта не даёт. Рабочий 3.18 на этом
устройстве контракт вообще не читает: `CONFIG_MTK_RAM_CONSOLE_USING_DRAM`
с фиксированными `0x43F00000/0x10000` (+ pstore `0x43F10000/0xE0000`,
console/pmsg по `0x10000`) — ровно окна reserved-memory стокового DTB; все
ошибки — мягкий `return`.

Сделано (P8, коммит `8b7af24d9`, образ `boot_49_p8.img`):
- `ram_console_parse_memory_info` возвращает ошибку вместо BUG;
- `ram_console_early_init`: при отсутствующем/битом LK-контракте —
  фолбэк на проверенную 3.18-раскладку m5c (fixed DRAM + явный
  `pstore_set_addr_size(0x43f10000, 0xe0000, 0x10000, 0x10000)`);
- чужая сигнатура буфера — warning, не BUG (init переинициализирует);
- `ram_console_fatal` удалён совсем: ничто в этом пути не имеет права
  BUG'ать до консоли.
- Строка-маркер `"no LK memory_info, using m5c fixed layout"` есть в
  Image (проверено strings) — она же будет первым признаком в last_kmsg.

Артефакт: `/srv/forge/android/m5c/kernel-m5c-4.9-lc/boot_49_p8.img`, sha256
`69519c71e810f1c12634fcdf5126acb6a6bdda8d408ebeeaa1e4caef35658c6e`,
9459712 B, boot (p7); DTB сток (md5 внутри проверен); System.map-p8 рядом
(адреса initcall'ов НЕ изменились: uart …bd54bc, ram_console …bd7bf8).
Маркеры 1–20 сохранены, читать как P7 (count=176).

Ожидание: веха 20 встанет (console_init пройден) и — главное — в
`/proc/last_kmsg` СЛЕДУЮЩЕЙ загрузки появится первый настоящий 4.9-лог
(грепать `4.9.188`, `m5c+`, `no LK memory_info`). Дальше диагностика
переходит с маркеров на текст.

## 2026-08-17 (P6 результат + P7) GIC-порт ПОДТВЕРЖДЁН; смерть в console_init

FACT (team-lead, `boot_49_p6.img`): слоты 1–17 на обоих адресах, 18 нет.
init_IRQ (14) и time_init (16) ПРОЙДЕНЫ портированным mt-gic и mt_gpt —
диагноз GIC подтверждён на железе. `console_init` (между 17 и 18) не
возвращается. 4.9-текста в last_kmsg по-прежнему нет.

FACT: в этой конфигурации собраны РОВНО два console-initcall'а
(`grep console_initcall` + наличие .o): `mtk_uart_console_init`
(drivers/misc/mediatek/uart/uart.c) и `ram_console_early_init`
(ram_console/mtk_ram_console.c). Адреса из System.map-p7:
- `mtk_uart_console_init` = `ffffff8008bd54bc` (в списке ПЕРВЫЙ)
- `ram_console_early_init` = `ffffff8008bd7bf8`

HYPOTHESIS (ранжирована): виснет `mtk_uart_console_init`. Cmdline несёт
`console=tty0 console=ttyMT3,921600n1` (в нашем boot — ttyMT), физического
UART на этом экземпляре нет; MT UART console-probe, ждущий железо/клок,
虚 — правдоподобный вис. Фальсификация — слот 19 (см. ниже) назовёт
функцию за одну загрузку.

Сделано (P7, коммит `484fe6b12`, образ `boot_49_p7.img`): маркер 19/20.
В `console_init()` (drivers/tty/tty_io.c) перед каждым `(*call)()`
пишется АДРЕС этого initcall в слот 19 (`forge_kmark_ptr`), после цикла —
веха 20. Выживший в слоте 19 адрес прямо укажет зависшую функцию по
System.map-p7.

Артефакт: `/srv/forge/android/m5c/kernel-m5c-4.9-lc/boot_49_p7.img`, sha256
`201a6d8217d947442fb96025f2bb652deb436fb6c959ac78637007c2f82c825d`,
9459712 B, boot (p7). System.map этой сборки сохранён рядом:
`kernel-m5c-4.9-lc/System.map-p7`. DTB сток (md5 внутри проверен).

Чтение (слот 19 на +160, 20 на +168 — читаем 176):
```
dd if=/dev/mem of=/tmp/fD.bin bs=1 skip=2130706432 count=176
dd if=/dev/mem of=/tmp/fE.bin bs=1 skip=2952790016 count=176
od -x /tmp/fD.bin ; od -x /tmp/fE.bin
```
На +160 (слот 19) — 8-байтовый АДРЕС (od -x: 4 слова LE). Расшифровка:
- `bd54bc..` (…8008bd54bc) → зависла `mtk_uart_console_init` → правим
  UART-console (убрать `console=ttyMT*` из cmdline или отключить его
  console-initcall; на этом юните UART нет).
- `bd7bf8..` (…8008bd7bf8) → зависла `ram_console_early_init` → правим
  ram console (parse reserved-memory / of_scan).
- Веха 20 на +168 стоит → оба console-initcall прошли, console_init вышел,
  смерть дальше в start_kernel (тогда ram console жив — сразу last_kmsg
  следующей загрузки на 4.9-текст).

СТАТУС: телефон занят (team-lead чинит регрессию дисплея на 3.18) — P7
ждёт освобождения устройства, НЕ прошивать до сигнала.

## 2026-08-17 (P5 результат + P6) Смерть в init_IRQ; портирован проверенный 3.18 mt-gic

FACT (team-lead, `boot_49_p5.img`, md5 470e7fc7…): слоты 1–13 на обоих
адресах, слот 14 ОТСУТСТВУЕТ → ядро умирает **внутри `init_IRQ`** — в GIC-
драйвере. Кэш-флаш C-маркеров работает (все C-вехи до 13 легли).

FACT (root cause на уровне исходников, без прошивки): наш РАБОЧИЙ 3.18 arm64
собирает `CONFIG_MTK_GIC=y` → `drivers/irqchip/irq-mt-gic.c`, а
`CONFIG_MTK_IRQ` у него **выключен**. В 4.9-lc `irq-mt-gic.c`/`MTK_GIC` нет
вообще; включённый мной `misc/mediatek/irq/mt6735/irq.c` (MTK_IRQ) в 4.9-lc
жил только в arm32-мире (mt6735 на 4.9-lc arm32-only) и на arm64 не работал
никогда. REJECTED: чинить arm32-драйвер; правильный ход — перенести
hardware-proven драйвер.

Сделано (P6, коммит `5b856e40a`, образ `boot_49_p6.img`): `irq-mt-gic.c`
(1489 строк) портирован из 3.18-дерева в 4.9 с фиксами API-дрейфа:
- `gic_irq()` теперь из mtk-gic-extend.h (у 4.9 он есть в хедере);
- `d->affinity` → `irq_data_get_affinity_mask(d)`;
- cascade-handler: сигнатура `(struct irq_desc *)`, `handle_bad_irq(desc)`;
- `gic_{dist,cpu}_{save,restore}` → `mt_*` (в 4.9 arm-gic.h есть одноимённые
  прототипы с другими сигнатурами);
- `set_irq_flags`/`IRQF_VALID` → `irq_set_status_flags`/`irq_set_probe`;
- `d->of_node` → `irq_domain_get_of_node(d)`;
- CPU_STARTING-нотифаер → `cpuhp_setup_state_nocalls(GIC_STARTING)`;
- `IS_ERR_VALUE(int)` → `irq_base < 0`;
- + 4 hwirq-хелпера для 4.9 cirq (`mt_irq_{set,get}_pending_hw`,
  `mt_irq_get_pending_vec`, `mt_irq_get_pol_hw`) подняты дословно из
  4.9 irq.c (те же глобалы GIC_DIST_BASE/INT_POL_CTL0).
`MACH_MT6735M` теперь select'ит `MTK_GIC` вместо `MTK_IRQ` — ровно как в
проверенном 3.18. Сборка чистая (EXIT=0, undefined refs нет).

Артефакт: `/srv/forge/android/m5c/kernel-m5c-4.9-lc/boot_49_p6.img`, sha256
`f4d4be3888e77bb56cfe113aaffaed3d6273a4fb703f7a22c87326b147141c83`,
9459712 B, boot (p7); DTB сток (md5 внутри проверен); маркеры 1–18 на
обоих адресах сохранены (те же команды чтения, count=176).
Ожидание: слоты пройдут 14 (init_IRQ/mt-gic) и дальше; при 17→18 ram
console оживёт и появится ПЕРВЫЙ 4.9-текст в last_kmsg следующей загрузки.

## 2026-08-17 (P4 результат + P5) setup_arch проходит ПОЛНОСТЬЮ; смерть в start_kernel

FACT (team-lead, `boot_49_p4.img`, md5 4b9d0ba4…): бутлуп ~50 с; на ОБОИХ
адресах прочитаны ВСЕ ДЕВЯТЬ вех (1–9). Т.е. `__enable_mmu` пережит,
early_ioremap работает, стоковый DTB просканирован (ms6),
`arm64_memblock_init` разобрал memory/reserved БЕЗ смерти (ms7 — мой главный
подозреваемый СНЯТ), `paging_init` поднял linear map (ms8), `setup_arch`
вернулся (ms9). C-маркеры через early_ioremap работают. 4.9-консоли по-
прежнему нет (last_kmsg = 3.18-сессия).

INFERENCE: смерть — в `start_kernel` между возвратом `setup_arch` и первым
flush printk (`console_init`). В окне: unflatten_device_tree, mm_init,
sched_init, init_IRQ (**mt-gic**), time_init (**mt_gpt**), console_init.
SMP через mt_psci/mt-boot — ЕЩЁ позже (rest_init→kernel_init→smp_init), в
окно этой смерти пока не попадает, но был назван риском №1.

Сделано (P5, коммит `61bada78c`, образ `boot_49_p5.img`): маркеры 10–18 в
`start_kernel`. early_ioremap к этому моменту снесён, поэтому `forge_kmark`
пишет через (кэшированный) linear map по `phys_to_virt` и **флашит
cacheline в DRAM** (`__flush_dcache_area`, 256 B) — иначе запись осела бы в
кэше и /dev/mem из recovery её бы не увидел при зависе. Точки:
- 10 = вернулись в start_kernel; 11 = mm_init; 12 = sched_init;
- 13 = ПЕРЕД init_IRQ (mt-gic); 14 = init_IRQ пройден;
- 15 = ПЕРЕД time_init (mt_gpt); 16 = time_init пройден;
- 17 = ПЕРЕД console_init; 18 = console_init пройден (ram console должен ожить).
`forge_kmark` — `__weak` пустышка в init/main.c, перекрыта сильным arm64-
определением (другие арки/сборки без маркеров всё равно линкуются).

Артефакт: `/srv/forge/android/m5c/kernel-m5c-4.9-lc/boot_49_p5.img`, sha256
`bf685a3ea1574565b18654e663795c8b5600f82d16a4b8f9540015788ea1eb84`,
9459712 B, boot (p7); DTB сток (md5 внутри проверен). asm-маркеры 1–4 обоих
адресов на месте (по 4 movz), C добавляет 5–18.

Чтение из recovery (слот 18 на +152, читаем с запасом):
```
dd if=/dev/mem of=/tmp/fD.bin bs=1 skip=2130706432 count=176   # 0x7f000000
dd if=/dev/mem of=/tmp/fE.bin bs=1 skip=2952790016 count=176   # 0xb0000000
od -x /tmp/fD.bin ; od -x /tmp/fE.bin
```
Слот вехи N — на +8+8*N (ms10→+88, 11→+96, 12→+104, 13→+112, 14→+120,
15→+128, 16→+136, 17→+144, 18→+152), в od -x как `41xx 4152`, xx=N в hex
(10→0a, 13→0d, 18→12).
БИСЕКЦИЯ:
- 9 есть, 10 нет → умер в прологе start_kernel (trap_init и т.п.) до 10.
- 13 есть, 14 нет → **init_IRQ / mt-gic** (наш GIC-драйвер).
- 15 есть, 16 нет → **time_init / mt_gpt** (наш clocksource).
- 17 есть, 18 нет → **console_init** сам.
- 18 есть, но нет текста 4.9 в last_kmsg → console_init прошёл, но ram
  console не пишет / умерли на первом же реальном drivers-initcall; тогда
  ram console инициализирован — проверить last_kmsg следующей загрузки на
  предмет 4.9-строк.

## 2026-08-17 (P3 результат + P4) asm-вехи 1-4 ЕСТЬ; смерть после MMU → C-маркеры

FACT (team-lead, `boot_49_p3.img`, on-device md5 51e62a08…): бутлуп; маркеры
ПРОЧИТАНЫ. На ОБОИХ адресах (0x7f000000, 0xb0000000) — магия `FORGE49` и все
четыре слота вех (1,2,3,4). Т.е. asm bring-up arm64 проходит ПОЛНОСТЬЮ: вход
в stext → el2_setup → page tables → cpu_setup. 4.9-консоли нет нигде
(last_kmsg/pstore — снова 3.18-сессия).

INFERENCE: смерть — в `__enable_mmu` / раннем C ДО console_initcall. Графт
arm64 жизнеспособен как минимум до включения MMU включительно — большой шаг
от «нет вывода вообще».

FACT: поле на +8 (D: `0000 7200…`, E: `e07c 000f…`) — это НЕиспользуемый слот
milestone-0 (8+8*0). Я пишу слоты с +16 (ms1). Значит +8 — просто прежнее
содержимое DRAM, не маркер; расхождение между адресами безвредно и
неинформативно.

FACT: `CONFIG_RELOCATABLE` и `CONFIG_RANDOMIZE_BASE` уже ВЫКЛючены (проверено)
— шага релокации в `__primary_switch` нет, эту переменную исключать не надо.

Сделано (P4, коммит `2c92bcc0b`, образ `boot_49_p4.img`): C-маркеры 5–9.
Физические asm-store не достают дальние scratch-страницы при включённом MMU,
поэтому вехи после MMU пишутся из C через `early_ioremap` (доступен с
`early_ioremap_init()`), в те же два адреса, тем же layout:
- 5 = setup_arch достигнут / early_ioremap жив
- 6 = setup_machine_fdt (стоковый DTB просканирован)
- 7 = arm64_memblock_init (memory/reserved ноды разобраны)
- 8 = paging_init (linear map поднят)
- 9 = конец setup_arch

Артефакт: `/srv/forge/android/m5c/kernel-m5c-4.9-lc/boot_49_p4.img`, sha256
`21a000f5be914f0d50665861436d62fea0eb30818dae0290b4011e240dfc33cf`,
9459712 B, boot (p7); DTB сток (md5 внутри проверен). Маркеры обоих адресов
в Image по 4 asm-movz; C-функция добавляет слоты 5–9.

Чтение из recovery — те же команды, но count побольше (слот 9 на +80):
```
dd if=/dev/mem of=/tmp/fD.bin bs=1 skip=2130706432 count=96   # 0x7f000000
dd if=/dev/mem of=/tmp/fE.bin bs=1 skip=2952790016 count=96   # 0xb0000000
od -x /tmp/fD.bin ; od -x /tmp/fE.bin
```
Слот вехи N — на смещении 8+8*N (ms5→+48, ms6→+56, ms7→+64, ms8→+72,
ms9→+80), в od -x виден как `41xx 4152`, xx = номер вехи.
БИСЕКЦИЯ (что скажет результат):
- 1-4 есть, 5 нет → умер в `__enable_mmu` ИЛИ прологе start_kernel до
  setup_arch (или до `early_ioremap_init`). Следующий шаг: маркер в
  `__primary_switched`/начале start_kernel.
- 5 есть, 6 нет → на `setup_machine_fdt` (парс стокового DTB).
- 6 есть, 7 нет → на `arm64_memblock_init` — ГЛАВНЫЙ подозреваемый для
  чужого DTB (memory/reserved-memory ноды).
- 7 есть, 8 нет → на `paging_init`.
- 8/9 есть, но нет 4.9-консоли → дошли до конца setup_arch, смерть дальше
  (unflatten/bootmem/psci/smp или console init) — тогда ram console вот-вот,
  смотреть last_kmsg следующей загрузки.

## 2026-08-17 (rev3) Оба адреса P2 опровергнуты; валидированы 0x7f/0xb0; recovery на нашем ядре

FACT (контроль team-lead, из recovery на нашем ядре, write→reboot→read):
- A `0x44800000` — МЁРТВ (после ребута — живые данные, не проба).
- B `0x4e100000` — МЁРТВ.
- C `0x5f000000` (1593835520) — ВЫЖИЛ.
- D `0x7f000000` (2130706432) — ВЫЖИЛ.
- E `0xb0000000` (2952790016) — ВЫЖИЛ.
Причина смерти A/B — их затирает ЧИТАТЕЛЬ, не умирающее ядро: TWRP-ramdisk
recovery ~10.3 МБ (0x44000000..~0x44A40000) поглощает 0x44800000; B сразу
за tags/DTB 0x4e000000. Урок: кандидат-адрес должен быть выше ramdisk/tags
recovery-ядра И проверен пробой.

Сделано (rev3, коммит `97851e559`, образ `boot_49_p3.img`):
- Маркеры пишутся в **D=0x7f000000** и **E=0xb0000000** (оба прошли
  контроль). C оставлен как задокументированный запас. Слоты по вехам как
  в rev2 (magic +0, слот на +8+8*ms).
- Проверено в Image: movz обоих адресов по 4 шт.; code0 остался 0x142c8000.

Артефакт: `/srv/forge/android/m5c/kernel-m5c-4.9-lc/boot_49_p3.img`, sha256
`caa57b3c5a9feedc3d72763507d4f57ebb1d060792eed24fd80788487a4f23e9`,
9459712 B, boot (p7); DTB сток (md5 внутри проверен), ramdisk тот же.

Чтение из recovery (busybox: dd bs=1 + десятичный skip; od без -t):
```
dd if=/dev/mem of=/tmp/fD.bin bs=1 skip=2130706432 count=48   # 0x7f000000
dd if=/dev/mem of=/tmp/fE.bin bs=1 skip=2952790016 count=48   # 0xb0000000
od -x /tmp/fD.bin ; od -x /tmp/fE.bin
```
Формат: +0..7 ASCII "FORGE49"; слот на веху N на смещении 8+8*N
(ms1→+16, ms2→+24, ms3→+32, ms4→+40); в `od -x` присутствующий слот
показывается как `41xx 4152` где `xx` = номер вехи (01..04). Все
достигнутые вехи видны одновременно.
Вехи: 1=вход в stext, 2=el2_setup пройден, 3=page tables построены,
4=cpu_setup пройден / включаем MMU.
Лестница: ни в D, ни в E нет "FORG" → LK не передал управление ядру
(decompress/заголовок); стоят слоты 1..N → умер после вехи N; все 4 + нет
last_kmsg 4.9 → умер на enable_mmu / relocate / раннем C до консоли.

REJECTED (осознанно НЕ делаю): дубль-копия в окно ram console 0x43f00000
для surfacing через /proc/last_kmsg. Чтобы сток/наше 3.18 ядро показало её
чисто в last_kmsg, надо воспроизвести структуру `ram_console_buffer`
(off_pl/off_lk/off_linux/off_console/log_start/log_size, проверка
`ram_console_check_header`) — иначе будет «header may be corrupted, raw
dump». Сырой splat туда рискует затереть то, что умирающее ядро само могло
бы записать. Два валидированных /dev/mem-адреса из recovery — чистый и
надёжный путь, дублирующий канал не нужен.

## 2026-08-17 (ещё позже) P1 тоже бутлуп; адрес маркера опровергнут контролем; rev2

FACT (team-lead): `boot_49_p1.img` прошит (code0 0x142c8000 подтверждён в
образе), бутлуп. Маркер по 0x43ff0800 — нули.

FACT (контрольный эксперимент team-lead, решающий): строка, записанная в
0x43ff0800 через /dev/mem из работающего Android, читается в той же сессии,
но после перезагрузки — НУЛИ. Окно 0x43ff0000 к тому же содержит живой
Thumb-код (реликты LK/TEE). REJECTED: «minirdump-окно сохраняется через
ребут» — адрес маркера rev1 не мог сработать в принципе.

FACT (новая возможность): recovery-раздел теперь несёт НАШЕ 3.18-ядро (#27)
с работающим /dev/mem (`CONFIG_DEVMEM=y`, STRICT_DEVMEM нет) — артефакт
`device/meizu/m5c/artifacts/recovery_ourkernel.img` (sha256 d998ffae…). У
стокового recovery-ядра DEVMEM был выключен (потому ранние чтения падали
ENXIO). Значит, читать маркер можно сразу из recovery — ему надо пережить
только reset+LK+загрузку recovery-ядра.

Сделано (rev2, коммит `a07fcc3d9`, образ `boot_49_p2.img`):
- Маркеры пишутся в ДВА кандидатных адреса свободного DRAM, оба подлежат
  контрольной валидации (write из recovery → reboot в recovery → read):
  **A = 0x44800000** (= 1149239296; за концом ramdisk ~0x44190000; тот же
  выбор, что FLOG на m681; memblock аллоцирует сверху вниз — при загрузке
  recovery низ памяти не трогается) и **B = 0x4e100000** (= 1309671424; за
  областью tags/DTB 0x4e000000).
- Слот на КАЖДЫЙ milestone (magic на +0, слот на +8+8*ms) — видно все
  достигнутые вехи, а не только последнюю: 1=вход в stext, 2=el2_setup
  пройден, 3=page tables построены, 4=cpu_setup пройден/включаем MMU.
- Верифицировано в Image: movz-инструкции обоих адресов по 4 шт.

Артефакт: `/srv/forge/android/m5c/kernel-m5c-4.9-lc/boot_49_p2.img`, sha256
`ca79a973c328f08177201508017170b12daa2fe3a8202015b94199b1891999ba`,
9459712 B, boot (p7); DTB сток (md5 внутри проверен), ramdisk тот же.

Чтение из recovery (busybox: od без -t, dd bs=1 + десятичный skip, awk нет):
```
dd if=/dev/mem of=/tmp/fA.bin bs=1 skip=1149239296 count=48   # 0x44800000
dd if=/dev/mem of=/tmp/fB.bin bs=1 skip=1309671424 count=48   # 0x4e100000
od -x /tmp/fA.bin; od -x /tmp/fB.bin
```
Ожидание: "FORG" "E49\0" на +0..7; слоты по +16/+24/+32/+40 = байт ms +
"KRAM" (LE-значение 0x004D52414B00 | ms... в od -x видно 4b0N 4152 004d).
Лестница: нет магии нигде → умер до входа в ядро ИЛИ оба адреса не
переживают (решает контрольная проба); слоты 1..N → умер после вехи N.

## 2026-08-17 (позже) P0 boot #1 УПАЛ до консоли → ранние маркеры + EFI off

FACT (от team-lead, прошивка `boot_49_p0.img`, on-device md5
`d6e64720a6211619886df807a34e3f6d` = артефакт, dd в by-name/boot 9459712 B):
устройство **бутлупит**, adb за 3 мин не поднялся. `/proc/last_kmsg` (65598 B),
`/sys/fs/pstore/console-ramoops` (65524 B) и expdb (2 MiB) — во ВСЕХ только
предыдущая 3.18-сессия (камерные строки S5K4H8, ~1923 s), НИ ОДНОЙ строки 4.9.

INFERENCE: ядро 4.9 умерло **до инициализации MTK ram console**, т.е. очень
рано — decompress / head.S / CPU bring-up / MMU / DTB parse, не в драйверах.

FACT (сравнение arm64-заголовков, team-lead): 4.9 P0 vs рабочее 3.18:
- code0 `0x91005a4d` (EFI-stub «MZ»-трюк, `CONFIG_EFI=y`) vs 3.18 `0x14000010`
  (простой branch); text_offset у обоих 0x80000, грузятся в 0x40080000.
- flags 4.9 = 0xa (бит 4K-страниц + PHYS_BASE), 3.18 = 0x0.

Сделано (коммит `8a07a96`, образ `boot_49_p1.img`):
1. **Ранние FORGE-маркеры в `arch/arm64/kernel/head.S`.** Магия `FORGE49` +
   u32 milestone пишется физически (MMU+dcache OFF, `dsb sy`) в
   **phys 0x43ff0800** — окно minirdump стокового DTB (`reg=<0x43ff0000
   0x10000>`, mapped + reserved, ни одно ядро не юзает его как обычную
   память, LK сохраняет; +0x800 чтобы миновать minidump-заголовок).
   Точки: **milestone 1** = вход в stext; **milestone 4** = asm bring-up
   закончен, MMU сейчас включится. Только x14/x15 (x0=FDT не тронут).
   Верифицировано: инструкция `movz x14,#0x43ff,lsl16` встречается в Image
   ровно 2 раза.
   - Лестница диагностики: НЕТ маркера → умер до входа в ядро
     (decompress/загрузчик); **1** → умер в el2_setup/page_tables/cpu_setup;
     **4** → умер на enable_mmu / relocate / раннем C до console_initcall;
     реальный last_kmsg 4.9 → дошёл до ram console.
2. **`CONFIG_EFI` off** → code0 стал `0x142c8000` (простой branch, класс как
   у 3.18), снят EFI-stub как переменная. flags остались 0xa (корректны для
   4.9: это page-size/PHYS_BASE биты новой спеки, LK грузит по фиксированному
   адресу и их игнорирует — зануление = ложь про размер страницы).

### Артефакт для прошивки: `boot_49_p1.img`

- Путь: `/srv/forge/android/m5c/kernel-m5c-4.9-lc/boot_49_p1.img`, sha256
  `ebd5ed10b4ca41fabcd6a861ac236ca7adf9f3c0a46950710e5af622cabc142d`,
  9459712 B, партиция **boot (p7)**.
- Состав: Image.gz #7 (markers, EFI off) + стоковый DTB (md5 e17a0910…
  проверен внутри по смещению kernel_size−69427) + LOS-ramdisk с forge-логгером.
- Как читать маркер из TWRP после бутлупа (root adb; телефон — bs числом,
  awk на устройстве НЕТ):
  ```
  dd if=/dev/mem of=/tmp/fmark.bin bs=1 skip=1140787200 count=32   # 0x43ff0800
  xxd /tmp/fmark.bin        # ждём "FORG E49\0" + u32 milestone (LE)
  ```
  milestone: 01 00 00 00 = дошёл до stext; 04 00 00 00 = прошёл asm-setup.
  Если магии нет вовсе — умер до входа в ядро (проверить, что LK вообще
  распаковал/прыгнул) ИЛИ /dev/mem не даёт читать этот адрес (тогда
  продублировать чтением всего окна `skip=1140785152 count=65536` =
  0x43ff0000..0x44000000 и грепнуть `FORG`).
- Плюс: если ядро всё же дойдёт до ram console — текст ляжет в last_kmsg
  следующей загрузки (адреса 0x43f00000/0x43f10000 из стокового DTB).

### HYPOTHESIS по причине ранней смерти (до маркеров — расставит их результат)

- H_early1: LK не любит EFH-stub code0 / несовпадение заголовка → не доходит
  даже до stext (маркер отсутствует). Митигация уже в p1 (EFI off).
- H_early2: DTB parse / `__create_page_tables` спотыкается о reserved-memory
  или memory-ноды (маркер=1, не 4). Проверка: если встанем на 1 — смотреть
  early fixmap/FDT-путь и memory node стокового DTB.
- H_early3: MMU enable / relocate (маркер=4, но нет last_kmsg). Проверка:
  RELOCATABLE/KASLR-путь, идентичность page-table кода.
- H_early4 (INFERENCE, вероятная): стоковый LK ждёт ровно тот формат
  ядра/заголовка, что у 3.18 (тот же LK грузит наше 3.18 #26). После EFI-off
  code0 совпал по классу — если p1 доходит до маркера, гипотеза H_early1
  подтверждается частично.

---

## 2026-08-17 Phase P0: arm64-графт 4.9-lc

### Дерево

- FACT: база — `nyancrimew/mtk-t-alps-release-q0-kernel-4.9-lc`, shallow-клон
  (единственный коммит `3aff4df04 Initial commit`), kernel **4.9.188**
  (`Makefile`: VERSION=4, PATCHLEVEL=9, SUBLEVEL=188). Рабочее дерево:
  `/srv/forge/android/m5c/kernel-m5c-4.9-lc`, ветка `m5c-arm64`.
- FACT: тулчейн — gcc 4.9 aarch64 из
  `los14.1-m5c-patched/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9`
  (тот же, каким собирается наше 3.18).

### Разведка перед графтом (все — FACT, проверено в дереве)

- `arch/arm64/Kconfig.platforms` 4.9-lc УЖЕ содержит MTK-платформы
  (`MACH_MT6758/MT6765/MT6761/MT6763/MT6580/MT3887`), перенесённые из arm32
  вместе с arm32-селектами (`CPU_V7`, `HAVE_SMP`, `NEED_MACH_MEMORY_H`) —
  select несуществующего символа в Kconfig игнорируется, прецедент в дереве
  массовый. Наш проверенный 3.18-arm64 `ARCH_MT6735M` устроен так же.
- Кастомный GIC-драйвер mt6735 (`drivers/misc/mediatek/irq/mt6735/irq.c`,
  `IRQCHIP_DECLARE("mediatek,mt6735-gic")` — тот же compatible, что в стоковом
  DTB) держит весь FIQ-код под `#if defined(CONFIG_FIQ_GLUE)` — на arm64
  символа нет, код выпадает сам.
- Сборочная механика appended-DTB на arm64 в дереве есть целиком:
  `CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE(_NAMES)`, цель `Image.gz-dtb`,
  `arch/arm64/boot/Makefile` конкатенирует Image.gz + DTB_OBJS.
- drvgen: `scripts/drvgen/drvgen.mk` генерит `cust.dtsi` из
  `drivers/misc/mediatek/dws/mt6735/k37mv1_bsp_k49.dws` (файл есть) тулзой
  `tools/dct/DrvGen.py`.
- MTKZU:android-10 (клон в скретчпаде) подтверждён как НЕ-графт: коммит
  `26fb53449 "Import A64 changes to m5c"` добавляет только
  `arch/arm64/configs/m5c_defconfig` (358 строк), `MACH_MT6735M` в их arm64
  Kconfig не заведён — их arm64-конфиг мёртвый. Совпадает с оценкой плана v2.

### Сделано (коммиты в kernel-m5c-4.9-lc, ветка m5c-arm64)

1. `arch/arm64/Kconfig.platforms`: добавлен `config MACH_MT6735M` — копия
   arm32-блока минус arm32-only селекты (`CPU_V7`, `VFP_OPT`,
   `NEED_MACH_MEMORY_H`, `ARM_CRYPTO`/`CRYPTO_*_ARM_CE`,
   `ARM_ERRATA_836870`, `ARM_MT6735_CPUIDLE` — последний вообще нигде не
   определён, select был мёртвый и на arm32). Оставлены реально существующие:
   `MTK_SYSTRACKER, MTK_SYS_CIRQ, MTK_EIC, MTK_GPIO, MTK_IRQ, PINCTRL_MT6735,
   MFD_SYSCON, CPU_IDLE, MTK_BASE_POWER, MTK_IRQ_NEW_DESIGN, MTK_POWER_GS,
   HW_RANDOM_MT67XX, SDCARD_FS, OVERLAY_FS` (все проверены grep'ом по
   Kconfig-ам дерева).
2. DTS: `mt6735m.dts`, `mt6735m-pinfunc.h`, `cust_mt6735_msdc.dtsi`,
   `k37mv1_bsp_k49.dts` скопированы из `arch/arm/boot/dts/` в
   `arch/arm64/boot/dts/mediatek/`; `#include <trusty.dtsi>` заменён на
   `"trusty.dtsi"` (angle-include не резолвится из подкаталога mediatek;
   файл в mediatek/ уже был). В `mediatek/Makefile` добавлено
   `dtb-$(CONFIG_MACH_MT6735M) += mt6735m.dtb k37mv1_bsp_k49.dtb`.
3. `arch/arm64/configs/m5c_defconfig` (новый): перевод
   `arch/arm/configs/k37mv1_bsp_k49_defconfig` на arm64 + P0-минимизация по
   плану §1.2(5). Ключевое:
   - `CONFIG_MACH_MT6735M=y`, `MTK_PLATFORM="mt6735"`,
     `ARCH_MTK_PROJECT="k37mv1_bsp_k49"` (проект референсный, пока не m5c —
     смена проекта = отдельная тема после P0);
   - **`CONFIG_COMPAT=y`** — наш userspace LOS 14.1 32-битный; в первом
     прогоне defconfig COMPAT не выставился (это ловил и
     `ANDROID_DEFAULT_SETTING`-warning про `ARMV8_DEPRECATED needs COMPAT`);
   - `CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE=y`,
     `NAMES="mediatek/k37mv1_bsp_k49"`;
   - выключено на P0: GPU (`MTK_GPU_SUPPORT`), дисплей (`MTK_FB`, `MTK_LCM`,
     `MTK_VIDEOX`, `MTK_CMDQ`, `MTK_SMI_EXT`), камеры (`MTK_IMGSENSOR`,
     `MTK_LENS`, `MTK_FLASHLIGHT`), тач (`INPUT_TOUCHSCREEN`), сенсоры
     (`MTK_SENSOR_SUPPORT`), связь (`MTK_COMBO*`, `MTK_BTIF`), модем
     (`MTK_ECCCI_DRIVER`), видеокодеки/JPEG, звук MTK;
   - оставлено живым: eMMC/MSDC (`MMC_MTK_PRO`, `MTK_EMMC_SUPPORT`), UART
     (`MTK_SERIAL`), PMIC wrap, clkmgr, GPT, watchdog, RTC, батарейный стек
     (`MTK_SMART_BATTERY`, GAUGE 20), USB musb (`USB_MTK_HDRC`+QMU),
     `MTK_RAM_CONSOLE`+`MTK_AEE_FEATURE` (канал last_kmsg), SELinux, ION.
4. FACT (сборочные грабли, чтобы не переоткрывать):
   - drvgen/dtboimg: при `CONFIG_MTK_DTBO_FEATURE=y` (default y!)
     `PROJ_DT_NAMES` берётся из `BUILD_ARM64_DTB_OVERLAY_IMAGE_NAMES` (у нас
     пусто) → `dtboimg.cfg` падает `mv: cannot stat`. Наш LK — не DTBO;
     лечится `# CONFIG_MTK_DTBO_FEATURE is not set` в defconfig.
   - Самый первый прогон make после голого defconfig упал там же из-за ещё
     не сгенерированного `include/config/auto.conf` — просто перезапуск.
   - Upstream-коммит дерева сделан из тарболла: у ВСЕХ `.sh/.py/.pl/.awk`
     и прешипнутых бинарей потерян exec-бит (`gen_vdso_offsets.sh`,
     `tools/dct/old_dct/DrvGen`, `scripts/dtc/dtc_overlay`) → серия
     `/bin/sh: Permission denied`. Вылечено tree-wide chmod-коммитом;
     заодно в дерево добавлен `.gitignore` (в тарболле его не было — без
     него `git add -A` тащит .o/.config в индекс).
   - `scripts/dtc`: `yylloc` — multiple definition под хостовым gcc 10+
     (`-fno-common`); `extern` в `dtc-lexer.lex.c_shipped` (тот же фикс,
     что первый коммит MTKZU).
   - drvgen вызывает `DrvGen.py` голым (`$(python)` пуст, shebang
     `/usr/bin/python` на хосте отсутствует) → в `drvgen.mk` добавлен
     `python ?= python2`; сам `.dws` старого (не-XML) формата, поэтому
     реально работает `tools/dct/old_dct/DrvGen` (статический ELF32,
     запускается на x86-64 хосте после chmod).
   - **Первый настоящий arm64-компилятивный дефект дерева**: в
     `arch/arm64/include/asm/cputype.h` MTK переименовал 5-аргументный
     `MIDR_RANGE` → `MIDR_IN_RANGE`, но `_MIDR_ALL_VERSIONS` остался на
     `MIDR_RANGE` → `cpufeature.c` (kpti_safe_list) не собирался. FACT:
     arm64-ветку этого дерева никто никогда не компилировал (ошибка в
     базовом arch-файле). Фикс: `_MIDR_ALL_VERSIONS` → `MIDR_IN_RANGE`.

### Закрытые ошибки компиляции/линковки arm64 (все — FACT, по build0N.log)

Хронология ошибок и фиксов (детали в сообщениях коммитов ветки `m5c-arm64`):

1. `cpufeature.c` (kpti_safe_list): `_MIDR_ALL_VERSIONS` разворачивался в
   переименованный `MIDR_RANGE` → `MIDR_IN_RANGE` (`arch/arm64/include/asm/
   cputype.h`). Ошибка в базовом arch-файле = arm64-ветку дерева никто
   никогда не собирал.
2. `mach/mt_gpt.h` и весь класс `mach/*` не находились: в
   `arch/arm64/Makefile` нет MTK include-пути; добавлен
   `-Idrivers/misc/mediatek/include/mt-plat/$(MTK_PLATFORM)/include` под
   `MACH_MT6735M` (зеркало arm32).
3. `cpuidle-mt6735.c`: 3.18-овский `cpu_init_idle()` → 4.9 `arm_cpuidle_init()`.
4. `mt_gpt.c`: печать указателя через `(u32)` — на arm64 int-cast error.
5. `irq/mt6735/irq.c`: нет `IOMEM()` на arm64 (68 ошибок одной причины) —
   добавлен локальный `#define`. FIQ-код уже был под `CONFIG_FIQ_GLUE`.
6. `mach/irqs.h`: `NR_IRQS redefined` против asm-generic — раскомментирован
   родной `#undef NR_IRQS`.
7. uart: подкаталожный `mt6735/Makefile` не имел `-I uart/include` и
   `-I uart/mt6735` (и юзал `$(CONFIG_MTK_PLATFORM)` с кавычками);
   `uart.c` не включал `linux/clk.h`. Плюс рантайм-мина: CCF-ветка
   `devm_clk_get()` завалила бы probe на стоковом DTB (в нём нет
   `skip_pinmux_clk`) — под `CONFIG_MTK_CLKMGR` теперь принудительный skip,
   клоки ведёт `platform_uart.c` через clkmgr, как на 3.18.
8. `mach/mt_thermal.h` → `"mt_gpufreq.h"`: в `base/power/mt6735/Makefile`
   не было `-I` собственного каталога.
9. m4u: `m4u_platform.c` (подкаталог `mt6735m/`) не видел свой же
   `m4u_reg.h` — добавлен `-I` собственного каталога.
10. `compat_ion.c`: `ION_MM_GET_IOVA(_EXT)` есть в компат-коде и в
    `struct ion_mm_data`, но отсутствовали в enum `ION_MM_CMDS` —
    полусмерженное состояние; добавлены в хвост enum.
11. devapc: ATF-ветка была под `TEE || ARM_PSCI || MTK_PSCI` → добавлен
    `CONFIG_ARM64` (на этой платформе arm64 всегда под ATF) и явный
    include `mach/mt_secure_api.h`.
12. **`mt_psci.c` — ключевая находка**: стоковый DTB m5c грузит CPU через
    `enable-method = "mt-boot"`, который реализует именно этот файл
    (`cpu_operations mt_cpu_psci_ops`), а `arch/arm64/kernel/cpu_ops.c`
    4.9-lc уже знает `mt_cpu_psci_ops` из коробки. Включён
    `CONFIG_MTK_PSCI=y` (ровно как в нашем проверенном 3.18 arm64
    конфиге); файл портирован на 4.9-сигнатуры cpu_operations
    (`cpu_init`/`cpu_init_idle` без device_node).
13. `MTK_IRQ_NEW_DESIGN`: потребители в `kernel/irq/{manage,proc}.c` есть,
    а провайдеры (`update_affinity_settings`, `irq_need_migrate_list`)
    были только в `arch/arm/kernel/irq.c` — блок перенесён дословно в
    `arch/arm64/kernel/irq.c` (в нашем 3.18 arm64 он там же).
14. systracker: `backtrace_64bit.c` ссылался на v2-глобал
    `BUS_PROTECT_BASE` при v1-интерфейсе — дамп-строка под guard.
15. cameraisp: собирался безусловно и тянул выключенные CMDQ/MMDVFS;
    Makefile посажен на `CONFIG_MTK_CAMERA_ISP` (P0: off). Грабля kbuild:
    при полностью пустом obj-y каталог оставляет СТАРЫЙ built-in.o и
    линкует его — поэтому dummy-объект оставлен безусловным (паттерн MTK).

### Результат P0: ядро собирается (FACT)

- `EXIT=0`, `arch/arm64/boot/Image.gz-dtb` = 6 076 510 B (build20.log).
- Баннер: `Linux version 4.9.188-m5c+ (n8n@n8nagent) (gcc 4.9) #6 SMP
  PREEMPT Mon Aug 17 15:40:53 MSK 2026`; magic arm64 `ARMd`, TEXT_OFFSET
  0x80000 — 64-битный Image, не zImage.
- Дерево: `/srv/forge/android/m5c/kernel-m5c-4.9-lc`, ветка `m5c-arm64`,
  14 коммитов поверх `Initial commit` (см. `git log --oneline`).

### Тестовый образ P0 (не прошит — прошивает владелец сессии)

- `boot_49_p0.img`, sha256
  `46b891adcfb4f8556f2e40121f6a8e4d6c3e5a581c888a3669b21a899d43e1d6`,
  9 459 712 B; путь (скретчпад):
  `/tmp/claude-1000/-srv-forge-android-m5c/145b2c58-…/scratchpad/boot_49_p0.img`.
- Состав: наш `Image.gz` (6 003 004 B) + **стоковый DTB** (69 427 B, md5
  `e17a091033c1e9188df898186be2761f` — проверен внутри образа по смещению
  kernel+6003004) + ramdisk LOS 14.1 c forge-логгером (1 616 110 B — тот же,
  что в `boot_k16.img`); заголовок mkbootimg скопирован с `boot_k16.img`
  (page 2048, kernel@0x40080000, ramdisk@0x44000000, tags@0x4e000000,
  cmdline `bootopt=64S3,32N2,64N2 androidboot.selinux=permissive
  buildvariant=userdebug`). gzip-поток ядра внутри образа проверен
  `gunzip -t`.
- Партиция: **boot (p7)**. Аварийный канал: TWRP на стоковом ядре.
- Ожидаемые маркеры успеха: `/proc/version` = `4.9.188-m5c+`; файлы
  логгера в `/data/forge/` (dmesg/heartbeat). Маркеры провала: last_kmsg
  через TWRP (`/proc/last_kmsg`), где встало.
- Osoбые точки внимания на первом боте 4.9 (что смотреть в dmesg):
  `mt-boot` cpu ops / подъём CPU1-3 (INFERENCE: путь mt_psci→
  cpu_psci_ops→ATF на 4.9 не проверялся на железе); mt_gpt/clocksource;
  msdc/eMMC mount `/data`; отсутствие дисплей-стека — экран останется на
  bootlogo LK, это ОЖИДАЕМО (MTK_FB off в P0).

### Подготовка Phase B (не гейтится загрузкой): jd9365 из стока

FACT: из `/home/valakas/m5c/kernel-reverse/vmlinux.elf` извлечены
байт-в-байт таблицы jd9365 (метод тот же, что для ili9881c): init VA
`0xffffffc00101fe40` — **227** записей (у нас в 3.18 дереве 225 —
расходится, диффать при порте), suspend VA `0xffffffc001023e18` — 6
записей. Самопроверка: первые записи пишут E1=0x93, E2=0x65 = compare_id
jd9365. Файлы: `captures/lcm-stock-tables/jd9365_stock_tables.c` (+
скрипт-экстрактор), коммит `2a23009`.

FACT: `jd9365_lcm_get_params` (декомпиляция `0xffffffc0004e559c`)
декодирован по словарю смещений, валидированному на ili9881c (все
верифицированные на железе значения ili9881c — PLL 212, LANE 4, порчи,
physical 62x110 — легли на те же offsets):

| поле | jd9365 | ili9881c (эталон, проверен на железе) |
|---|---|---|
| mode | 1 (SYNC_PULSE_VDO) | 1 |
| LANE_NUM | 4 | 4 |
| vsa / vbp / vfp | 4 / 12 / 24 | 4 / 16 / 20 |
| hsa / hbp / hfp | 30 / 60 / 66 | 20 / 70 / 70 |
| PLL_CLOCK | 212 | 212 |
| ssc_disable | 1 | 1 |
| noncont_clock / period | 1 / 2 | нет |
| HS_TRAIL | 6 | 6 |
| physical w×h, мм | 62×110 | 62×110 |
| esd cmd/expect | 0x09 → 0x80,0x03 (count 3) | 0x0A → 0x9C |

Подтверждено требование плана: панели НЕ делят тайминги (порчи и ESD
разные) — таблицы и параметры на 4.9 несём раздельно. Один нерешённый
байт: запись `*(u8*)(param+0xbc)=0x33` (offset 752) у jd9365 — за
пределами esd-таблицы нашего заголовка (в нашем layout это
switch_mode_enable); разобрать при порте (сдвиг stock-структуры +8
локализован хвостом ≥868, так что это может быть реально
switch_mode_enable=0x33 у стока — HYPOTHESIS, проверка: сверка с
jd9365-декомпиляцией структуры или игнор, поле не используется в
vdo-режиме).

### HYPOTHESIS к следующей загрузке

- H1: ядро дойдёт до init и логгера (проверка: `/data/forge/*` свежие).
- H2 (риск): SMP bring-up через mt-boot на 4.9 может отличаться от 3.18
  (в 3.18 `mt_psci` использует те же cpu_psci_ops+MTCMOS; ATF тот же).
  Фальсификация: в dmesg `CPU1: failed to boot` / зависание до logger.
- H3 (риск): `clk_buf`/`spm`-инициализация clkmgr-пути может залипнуть на
  ранней фазе (класс m681-проблем НЕ ожидается — clkmgr, не CCF; см. план
  §4 «рисков m681-типа нет»). Фальсификация: пустой /data/forge при живом
  last_kmsg с последней строкой в области spm/clkmgr.

