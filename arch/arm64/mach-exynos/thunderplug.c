/* Copyright (c) 2015, Varun Chitre <varun.chitre15@gmail.com>
 *
 * This software is licensed under the terms of the GNU General Public
 * License version 2, as published by the Free Software Foundation, and
 * may be copied, distributed, and modified under those terms.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * A simple hotplugging driver.
 * Compatible from dual core CPUs to Octa Core CPUs
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/hrtimer.h>
#include <linux/init.h>
#include <linux/device.h>
#include <linux/input.h>
#include <linux/slab.h>
#include <linux/cpu.h>
#include <linux/cpufreq.h>
#ifdef CONFIG_STATE_NOTIFIER
#include <linux/state_notifier.h>
#endif

#define DEBUG				0

#define THUNDERPLUG			"thunderplug"

#define DRIVER_VERSION			5
#define DRIVER_SUBVER			4

#define DEFAULT_CPU_LOAD_THRESHOLD	(90)

#define HOTPLUG_ENABLED			(0)
#define STARTDELAY			1000

#define DEF_SAMPLING_MS			(20)
#define MIN_SAMLING_MS			(10)
#define MIN_CPU_UP_TIME			(300)

#define DEFAULT_BOOST_LOCK_DUR		500 * 1000L
#define DEFAULT_NR_CPUS_BOOSTED		2
#define MIN_INPUT_INTERVAL		150 * 1000L

static bool isSuspended = false;

static int now[8], last_time[8];
struct cpufreq_policy old_policy[NR_CPUS];
static struct workqueue_struct *tplug_wq;
static struct delayed_work tplug_work;

static unsigned int last_load[8] = { 0 };
static u64 last_boost_time;

struct cpu_load_data {
	u64 prev_cpu_idle;
	u64 prev_cpu_wall;
	unsigned int avg_load_maxfreq;
	unsigned int cur_load_maxfreq;
	unsigned int samples;
	unsigned int window_size;
	cpumask_var_t related_cpus;
};

static struct thunder_param_struct {
	unsigned int cpus_boosted;
	unsigned int target_cpus;
	u64 boost_lock_dur;
	u64 last_input;
	int hotplug_suspend;
	unsigned int sampling_time;
	int suspend_cpu_num;
	int resume_cpu_num;
	int max_core_online;
	int min_core_online;
	int tplug_hp_enabled;
	int load_threshold;
	struct work_struct up_work;
	struct notifier_block thunder_state_notif;
} thunder_param = {
	.cpus_boosted = DEFAULT_NR_CPUS_BOOSTED,
	.boost_lock_dur = DEFAULT_BOOST_LOCK_DUR,
	.suspend_cpu_num = 3,
	.resume_cpu_num = (NR_CPUS -1),
	.max_core_online = NR_CPUS,
	.min_core_online = 1,
	.sampling_time = DEF_SAMPLING_MS,
	.load_threshold = DEFAULT_CPU_LOAD_THRESHOLD,
	.tplug_hp_enabled = HOTPLUG_ENABLED,
	.hotplug_suspend = 0,
};

static DEFINE_PER_CPU(struct cpu_load_data, cpuload);

static inline void offline_cpus(void)
{
	unsigned int cpu;

	for (cpu = NR_CPUS - 1; cpu >
			(thunder_param.suspend_cpu_num - 1); cpu--) {
		if (cpu_online(cpu))
			cpu_down(cpu);
	}
	pr_info("%s: %d cpus were offlined\n",
			THUNDERPLUG,
			(NR_CPUS - thunder_param.suspend_cpu_num));
}

static inline void cpus_online_all(void)
{
	unsigned int cpu;

	if (DEBUG)
		pr_info("%s: resume_cpu_num = %d\n",THUNDERPLUG,
				thunder_param.resume_cpu_num);

	for (cpu = 1; cpu <= thunder_param.resume_cpu_num; cpu++) {
		if (cpu_is_offline(cpu))
			cpu_up(cpu);
	}

	pr_info("%s: all cpus were onlined\n", THUNDERPLUG);
}

static ssize_t thunderplug_hotplug_suspend_show(struct kobject *kobj,
                        struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%d", thunder_param.hotplug_suspend);
}

static ssize_t thunderplug_hotplug_suspend_store(struct kobject *kobj,
			struct kobj_attribute *attr,
			const char *buf, size_t count)
{
	int val;

	sscanf(buf, "%d", &val);

	switch(val) {
		case 0:
		case 1:
			thunder_param.hotplug_suspend = val;
			break;
		default:
			pr_info("%s: invalid value! set 0 or 1 here.\n",
					THUNDERPLUG);
			thunder_param.hotplug_suspend = 0;
			break;
	}
	return count;
}

static ssize_t thunderplug_suspend_cpus_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%d", thunder_param.suspend_cpu_num);
}

static ssize_t thunderplug_suspend_cpus_store(struct kobject *kobj,
			struct kobj_attribute *attr,
			const char *buf, size_t count)
{
	int val;

	sscanf(buf, "%d", &val);

	if (val < 1 || val > NR_CPUS)
		pr_info("%s: suspend cpus off-limits\n", THUNDERPLUG);
	else
		thunder_param.suspend_cpu_num = val;

	return count;
}

static ssize_t thunderplug_max_core_online_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%d", thunder_param.max_core_online);
}

static ssize_t __ref thunderplug_max_core_online_store(struct kobject *kobj,
			struct kobj_attribute *attr,
			const char *buf, size_t count)
{
	int val;

	sscanf(buf, "%d", &val);

	switch(val) {
		case 1:
		case 2:
		case 3:
		case 4:
			if (thunder_param.tplug_hp_enabled &&
					thunder_param.max_core_online != val) {
				thunder_param.max_core_online = val;
				offline_cpus();
				cpus_online_all();
			}
			break;
		default:
			pr_info("%s: invalid max_core value\n",
				THUNDERPLUG);
			break;
	}
	return count;
}

static ssize_t thunderplug_min_core_online_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%d", thunder_param.min_core_online);
}

static ssize_t __ref thunderplug_min_core_online_store(struct kobject *kobj,
                        struct kobj_attribute *attr,
                        const char *buf, size_t count)
{
	int val;

	sscanf(buf, "%d", &val);

	switch(val) {
		case 1:
		case 2:
		case 3:
		case 4:
			if (thunder_param.tplug_hp_enabled &&
					thunder_param.min_core_online != val) {
				thunder_param.min_core_online = val;
				offline_cpus();
				cpus_online_all();
			}
			break;
		default:
			pr_info("%s: invalid min_core value\n",
				THUNDERPLUG);
			break;
	}
	return count;
}

static ssize_t thunderplug_sampling_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%d", thunder_param.sampling_time);
}

static ssize_t thunderplug_sampling_store(struct kobject *kobj,
			struct kobj_attribute *attr,
			const char *buf, size_t count)
{
	int val;

	sscanf(buf, "%d", &val);

	if (val >= MIN_SAMLING_MS)
		thunder_param.sampling_time = val;

	return count;
}

static ssize_t thunderplug_load_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%d", thunder_param.load_threshold);
}

static ssize_t thunderplug_load_store(struct kobject *kobj,
			struct kobj_attribute *attr,
			const char *buf, size_t count)
{
	int val;

	sscanf(buf, "%d", &val);

	if (val > 10)
		thunder_param.load_threshold = val;

	return count;
}

static ssize_t thunderplug_boost_lock_duration_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%llu\n",
			div_u64(thunder_param.boost_lock_dur, 1000));
}

static ssize_t thunderplug_boost_lock_duration_store(struct kobject *kobj,
			struct kobj_attribute *attr,
			const char *buf, size_t count)
{
	int ret;
	u64 val;

	ret = sscanf(buf, "%llu", &val);
	if (ret != 1)
		return -EINVAL;

	thunder_param.boost_lock_dur = val * 1000;

	return count;
}

static ssize_t thunderplug_cpus_boosted_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%u\n", thunder_param.cpus_boosted);
}

static ssize_t thunderplug_cpus_boosted_store(struct kobject *kobj,
			struct kobj_attribute *attr,
			const char *buf, size_t count)
{
	int ret;
	unsigned int val;

	ret = sscanf(buf, "%u", &val);
	if (ret != 1 || val < 1 || val > CONFIG_NR_CPUS)
		return -EINVAL;

	thunder_param.cpus_boosted = val;

	return count;
}

static unsigned int get_curr_load(unsigned int cpu)
{
	int ret;
	unsigned int idle_time, wall_time;
	unsigned int cur_load;
	u64 cur_wall_time, cur_idle_time;
	struct cpu_load_data *pcpu = &per_cpu(cpuload, cpu);
	struct cpufreq_policy policy;

	ret = cpufreq_get_policy(&policy, cpu);
	if (ret)
		return -EINVAL;

	cur_idle_time = get_cpu_idle_time(cpu, &cur_wall_time, 0);

	wall_time = (unsigned int) (cur_wall_time - pcpu->prev_cpu_wall);
	pcpu->prev_cpu_wall = cur_wall_time;

	idle_time = (unsigned int) (cur_idle_time - pcpu->prev_cpu_idle);
	pcpu->prev_cpu_idle = cur_idle_time;

	if (unlikely(!wall_time || wall_time < idle_time))
		return 0;

	cur_load = 100 * (wall_time - idle_time) / wall_time;

	return cur_load;
}

static void __cpuinit tplug_work_fn(struct work_struct *work)
{
	int i;
	unsigned int load[8], avg_load[8];
	unsigned int nr_cpu_online;
	u64 time_now;

	if (!thunder_param.tplug_hp_enabled)
		return;

	for (i = 0 ; i < thunder_param.max_core_online - 1; i++) {
		if (cpu_online(i))
			load[i] = get_curr_load(i);
		else
			load[i] = 0;

		avg_load[i] = ((int) load[i] + (int) last_load[i]) / 2;
		last_load[i] = load[i];
	}

	for (i = 0 ; i < thunder_param.max_core_online - 1; i++) {
		if (cpu_online(i) && avg_load[i] >
				thunder_param.load_threshold &&
				cpu_is_offline(i + 1)) {
			if (DEBUG)
				pr_info("%s : bringing back cpu%d\n",
					THUNDERPLUG,i);
			if (!((i + 1) > 7)) {
				last_time[i + 1] = ktime_to_ms(ktime_get());
				cpu_up(i + 1);
			}
		} else if (cpu_online(i) && avg_load[i] <
				thunder_param.load_threshold &&
				cpu_online(i + 1)) {
			if (DEBUG)
				pr_info("%s : offlining cpu%d\n",
					THUNDERPLUG,i);
			/* count online cores */
			nr_cpu_online = num_online_cpus();

			if (nr_cpu_online > thunder_param.min_core_online) {
				/*
				 * check if core touch boosted
				 * before cpu_down
				 */
				time_now = ktime_to_us(ktime_get());
				if (nr_cpu_online <=
						thunder_param.cpus_boosted &&
						(time_now -
						thunder_param.last_input <
						thunder_param.boost_lock_dur))
					goto reschedule;

				if (!(i + 1) == 0) {
					now[i + 1] = ktime_to_ms(ktime_get());
					if ((now[i + 1] - last_time[i + 1]) >
							MIN_CPU_UP_TIME)
						cpu_down(i + 1);
				}
			}
		}
	}

reschedule:
	queue_delayed_work_on(0, tplug_wq, &tplug_work,
			msecs_to_jiffies(thunder_param.sampling_time));
}

#ifdef CONFIG_STATE_NOTIFIER
static void __ref thunderplug_suspend(void)
{
	if (isSuspended == false) {
		isSuspended = true;
		cancel_delayed_work_sync(&tplug_work);
		offline_cpus();
		pr_info("%s: suspend\n", THUNDERPLUG);
	}
}

static void __ref thunderplug_resume(void)
{
	if (isSuspended == true) {
		isSuspended = false;
		cpus_online_all();
		pr_info("%s: resume\n", THUNDERPLUG);
		queue_delayed_work_on(0, tplug_wq, &tplug_work,
				msecs_to_jiffies(thunder_param.sampling_time));
	}
}

static int state_notifier_callback(struct notifier_block *this,
				unsigned long event, void *data)
{
	if (!thunder_param.hotplug_suspend)
		return NOTIFY_OK;

	if (!thunder_param.tplug_hp_enabled)
		return NOTIFY_OK;

	switch (event) {
		case STATE_NOTIFIER_ACTIVE:
			thunderplug_resume();
			break;
		case STATE_NOTIFIER_SUSPEND:
			thunderplug_suspend();
			break;
		default:
			break;
	}
	return NOTIFY_OK;
}
#endif

static void __ref cpu_up_work(struct work_struct *work)
{
	int cpu;
	unsigned int target = thunder_param.target_cpus;

	for_each_cpu_not(cpu, cpu_online_mask) {
		if (target <= num_online_cpus())
			break;
		if (cpu == 0)
			continue;
		cpu_up(cpu);
	}
}

static void online_cpu(unsigned int target)
{
	unsigned int online_cpus;

	online_cpus = num_online_cpus();

	/*
	 * Do not online more CPUs if max_cpus_online reached
	 * and cancel online task if target already achieved.
	 */
	if (target <= online_cpus ||
			online_cpus >= thunder_param.max_core_online)
		return;

	thunder_param.target_cpus = target;
	queue_work_on(0, tplug_wq, &thunder_param.up_work);
}

static void thunder_input_event(struct input_handle *handle, unsigned int type,
				unsigned int code, int value)
{
	u64 time_now;

	if (isSuspended == true)
		return;
	if (!thunder_param.tplug_hp_enabled)
		return;

	time_now = ktime_to_us(ktime_get());
	thunder_param.last_input = time_now;
	if (time_now - last_boost_time < MIN_INPUT_INTERVAL)
		return;

	if (num_online_cpus() >= thunder_param.cpus_boosted ||
			thunder_param.cpus_boosted <=
			thunder_param.min_core_online)
		return;

	online_cpu(thunder_param.cpus_boosted);
	last_boost_time = ktime_to_us(ktime_get());
}

static int thunder_input_connect(struct input_handler *handler,
				 struct input_dev *dev,
				 const struct input_device_id *id)
{
	struct input_handle *handle;
	int err;

	handle = kzalloc(sizeof(struct input_handle), GFP_KERNEL);
	if (!handle)
		return -ENOMEM;

	handle->dev = dev;
	handle->handler = handler;
	handle->name = handler->name;

	err = input_register_handle(handle);
	if (err)
		goto err_register;

	err = input_open_device(handle);
	if (err)
		goto err_open;

	return 0;
err_open:
	input_unregister_handle(handle);
err_register:
	kfree(handle);
	return err;
}

static void thunder_input_disconnect(struct input_handle *handle)
{
	input_close_device(handle);
	input_unregister_handle(handle);
	kfree(handle);
}

static const struct input_device_id thunder_ids[] = {
	{
		.flags = INPUT_DEVICE_ID_MATCH_EVBIT |
			 INPUT_DEVICE_ID_MATCH_ABSBIT,
		.evbit = { BIT_MASK(EV_ABS) },
		.absbit = { [BIT_WORD(ABS_MT_POSITION_X)] =
			    BIT_MASK(ABS_MT_POSITION_X) |
			    BIT_MASK(ABS_MT_POSITION_Y) },
	}, /* multi-touch touchscreen */
	{
		.flags = INPUT_DEVICE_ID_MATCH_KEYBIT |
			 INPUT_DEVICE_ID_MATCH_ABSBIT,
		.keybit = { [BIT_WORD(BTN_TOUCH)] = BIT_MASK(BTN_TOUCH) },
		.absbit = { [BIT_WORD(ABS_X)] =
			    BIT_MASK(ABS_X) | BIT_MASK(ABS_Y) },
	}, /* touchpad */
	{ },
};

static struct input_handler thunder_input_handler = {
	.event		= thunder_input_event,
	.connect	= thunder_input_connect,
	.disconnect	= thunder_input_disconnect,
	.name		= THUNDERPLUG,
	.id_table	= thunder_ids,
};

static ssize_t thunderplug_hp_enabled_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%d", thunder_param.tplug_hp_enabled);
}

static ssize_t __ref thunderplug_hp_enabled_store(struct kobject *kobj,
			struct kobj_attribute *attr,
			const char *buf, size_t count)
{
	int val, last_val;
	int ret = 0, cpu;

	sscanf(buf, "%d", &val);

	last_val = thunder_param.tplug_hp_enabled;
	switch(val) {
		case 0:
		case 1:
			thunder_param.tplug_hp_enabled = val;
			break;
		default:
			pr_info("%s : invalid choice\n", THUNDERPLUG);
			break;
	}

	if (thunder_param.tplug_hp_enabled == 1 && !last_val) {
		pr_info("%s : Starting hotplug driver\n", THUNDERPLUG);
		tplug_wq = alloc_workqueue("tplug",
				WQ_HIGHPRI | WQ_FREEZABLE, 0);
		if (!tplug_wq) {
			pr_err("%s: Failed to allocate hotplug workqueue\n",
				__FUNCTION__);
			thunder_param.tplug_hp_enabled = 0;
			return 0;
		}
		ret = input_register_handler(&thunder_input_handler);
		if (ret) {
			pr_err("%s: Failed to register input handler: %d\n",
					THUNDERPLUG, ret);
			return 0;
		}
		INIT_DELAYED_WORK(&tplug_work, tplug_work_fn);
		INIT_WORK(&thunder_param.up_work, cpu_up_work);
		queue_delayed_work_on(0, tplug_wq, &tplug_work,
				msecs_to_jiffies(thunder_param.sampling_time));
	} else if (thunder_param.tplug_hp_enabled == 1 && last_val == 1) {
		pr_info("%s : Already Working\n", THUNDERPLUG);
	} else if (thunder_param.tplug_hp_enabled == 0 && last_val == 0) {
		pr_info("%s : Already Offline\n", THUNDERPLUG);
	} else {
		if (last_val) {
			input_unregister_handler(&thunder_input_handler);
			flush_workqueue(tplug_wq);
			cancel_work_sync(&thunder_param.up_work);
			cancel_delayed_work_sync(&tplug_work);
			destroy_workqueue(tplug_wq);

			/* Put all sibling cores to sleep */
			for_each_online_cpu(cpu) {
				if (cpu == 0)
					continue;
				cpu_down(cpu);
			}
			pr_info("%s : Stopping hotplug driver\n", THUNDERPLUG);
		}
	}

	return count;
}

static struct kobj_attribute thunderplug_hp_enabled_attribute =
	__ATTR(hotplug_enabled,
		0666, thunderplug_hp_enabled_show,
		thunderplug_hp_enabled_store);

static ssize_t thunderplug_ver_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "ThunderPlug %u.%u", DRIVER_VERSION,
			DRIVER_SUBVER);
}

static struct kobj_attribute thunderplug_ver_attribute =
	__ATTR(version,
		0444, thunderplug_ver_show, NULL);

static struct kobj_attribute thunderplug_hotplug_suspend_attribute =
	__ATTR(hotplug_suspend,
		0666, thunderplug_hotplug_suspend_show,
		thunderplug_hotplug_suspend_store);

static struct kobj_attribute thunderplug_suspend_cpus_attribute =
	__ATTR(suspend_cpus,
		0666, thunderplug_suspend_cpus_show,
		thunderplug_suspend_cpus_store);

static struct kobj_attribute thunderplug_max_core_online_attribute =
	__ATTR(max_core_online,
		0666, thunderplug_max_core_online_show,
		thunderplug_max_core_online_store);

static struct kobj_attribute thunderplug_min_core_online_attribute =
	__ATTR(min_core_online,
		0666, thunderplug_min_core_online_show,
		thunderplug_min_core_online_store);

static struct kobj_attribute thunderplug_sampling_attribute =
	__ATTR(sampling_rate,
		0666, thunderplug_sampling_show,
		thunderplug_sampling_store);

static struct kobj_attribute thunderplug_load_attribute =
	__ATTR(load_threshold,
		0666, thunderplug_load_show,
		thunderplug_load_store);

static struct kobj_attribute thunderplug_boost_lock_duration_attribute =
	__ATTR(boost_lock_duration,
		0666, thunderplug_boost_lock_duration_show,
		thunderplug_boost_lock_duration_store);

static struct kobj_attribute thunderplug_cpus_boosted_attribute =
	__ATTR(cpus_boosted,
		0666, thunderplug_cpus_boosted_show,
		thunderplug_cpus_boosted_store);

static struct attribute *thunderplug_attrs[] = {
	&thunderplug_ver_attribute.attr,
	&thunderplug_hotplug_suspend_attribute.attr,
	&thunderplug_suspend_cpus_attribute.attr,
	&thunderplug_max_core_online_attribute.attr,
	&thunderplug_min_core_online_attribute.attr,
	&thunderplug_sampling_attribute.attr,
	&thunderplug_load_attribute.attr,
	&thunderplug_hp_enabled_attribute.attr,
	&thunderplug_boost_lock_duration_attribute.attr,
	&thunderplug_cpus_boosted_attribute.attr,
	NULL,
};

static struct attribute_group thunderplug_attr_group =
{
	.attrs = thunderplug_attrs,
};

static struct kobject *thunderplug_kobj;

static int __init thunderplug_init(void)
{
	int ret = 0;
	int sysfs_result;

	printk(KERN_DEBUG "[%s]\n",__func__);

	thunderplug_kobj = kobject_create_and_add("thunderplug", kernel_kobj);
	if (!thunderplug_kobj) {
		pr_err("%s Interface create failed!\n",
				__FUNCTION__);
		return -ENOMEM;
	}

	sysfs_result = sysfs_create_group(thunderplug_kobj,
			&thunderplug_attr_group);
	if (sysfs_result) {
		pr_info("%s sysfs create failed!\n", __FUNCTION__);
		kobject_put(thunderplug_kobj);
	}

	if (thunder_param.tplug_hp_enabled) {
		tplug_wq = alloc_workqueue("tplug",
				WQ_HIGHPRI | WQ_FREEZABLE, 0);
		if (!tplug_wq) {
			pr_err("%s: Failed to allocate hotplug workqueue\n",
				__FUNCTION__);
			ret = -ENOMEM;
			goto err_out;
		}
		INIT_DELAYED_WORK(&tplug_work, tplug_work_fn);
		queue_delayed_work_on(0, tplug_wq, &tplug_work,
					msecs_to_jiffies(STARTDELAY));
	}

#ifdef CONFIG_STATE_NOTIFIER
	thunder_param.thunder_state_notif.notifier_call =
				state_notifier_callback;
	if (state_register_client(&thunder_param.thunder_state_notif)) {
		pr_err("%s: Failed to register State notifier callback\n",
			__func__);
		goto err_out;
	}
#endif

	pr_info("%s: init\n", THUNDERPLUG);

	return ret;

err_out:
	thunder_param.tplug_hp_enabled = 0;
	destroy_workqueue(tplug_wq);

	return ret;
}

MODULE_LICENSE("GPL and additional rights");
MODULE_AUTHOR("Varun Chitre <varun.chitre15@gmail.com>");
MODULE_DESCRIPTION("Hotplug driver for ARM SoCs");
late_initcall(thunderplug_init);
