/*
 * SPDX-License-Identifier: MIT
 *
 * Enables a layer when a processed input event has a non-zero value, then
 * disables it after a fixed duration. Unlike ZMK's standard temp-layer
 * processor, later input events do not extend the deadline.
 */

#define DT_DRV_COMPAT zmk_input_processor_fixed_temp_layer

#include <zephyr/device.h>
#include <zephyr/kernel.h>
#include <zephyr/sys/atomic.h>

#include <drivers/input_processor.h>
#include <zmk/keymap.h>

#if DT_HAS_COMPAT_STATUS_OKAY(DT_DRV_COMPAT)

struct fixed_temp_layer_data {
    struct k_work_delayable disable_work;
    atomic_t active;
    uint8_t layer;
};

static void disable_layer(struct k_work *work) {
    struct k_work_delayable *delayable = k_work_delayable_from_work(work);
    struct fixed_temp_layer_data *data =
        CONTAINER_OF(delayable, struct fixed_temp_layer_data, disable_work);

    if (atomic_cas(&data->active, 1, 0)) {
        zmk_keymap_layer_deactivate(data->layer);
    }
}

static int handle_event(const struct device *dev, struct input_event *event, uint32_t layer,
                        uint32_t duration_ms, struct zmk_input_processor_state *state) {
    struct fixed_temp_layer_data *data = dev->data;

    if (layer >= ZMK_KEYMAP_LAYERS_LEN) {
        return -EINVAL;
    }

    /* Scalers can emit zero-valued events while accumulating remainders.
     * Those events must not activate or prolong SCROLL MENU. */
    if (event->value == 0) {
        return ZMK_INPUT_PROC_CONTINUE;
    }

    if (atomic_cas(&data->active, 0, 1)) {
        data->layer = layer;
        zmk_keymap_layer_activate(layer);

        if (duration_ms > 0) {
            k_work_reschedule(&data->disable_work, K_MSEC(duration_ms));
        }
    }

    return ZMK_INPUT_PROC_CONTINUE;
}

static int fixed_temp_layer_init(const struct device *dev) {
    struct fixed_temp_layer_data *data = dev->data;

    atomic_clear(&data->active);
    k_work_init_delayable(&data->disable_work, disable_layer);
    return 0;
}

static const struct zmk_input_processor_driver_api fixed_temp_layer_api = {
    .handle_event = handle_event,
};

#define FIXED_TEMP_LAYER_INST(n)                                                                  \
    static struct fixed_temp_layer_data fixed_temp_layer_data_##n;                               \
    DEVICE_DT_INST_DEFINE(n, fixed_temp_layer_init, NULL, &fixed_temp_layer_data_##n, NULL,       \
                          POST_KERNEL, CONFIG_KERNEL_INIT_PRIORITY_DEFAULT,                       \
                          &fixed_temp_layer_api);

DT_INST_FOREACH_STATUS_OKAY(FIXED_TEMP_LAYER_INST)

#endif /* DT_HAS_COMPAT_STATUS_OKAY(DT_DRV_COMPAT) */
