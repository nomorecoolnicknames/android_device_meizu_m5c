# Display
# forge_hwc replaces the vendor hwcomposer blob (broken against the 4.9
# kernel: frames stall in its internal queues) — see hwcomposer/.
PRODUCT_PACKAGES += \
    hwcomposer.mt6737m

PRODUCT_PACKAGES += \
    libstlport \
    libgui_ext \
    libui_ext \
    libion_mtk \
    libion \
    librrc