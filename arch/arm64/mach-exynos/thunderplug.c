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
static struct notifier_block thunder_state_notif;
#endif

#define DEBUG				0

#define THUNDERPLUG			"thunderplug"

#define DRIVER_VERSION			5
#define DRIVER_SUBVER			3

#define BOOST_ENABLED			1
#define BOOST_DISABLED			0

#define POWER_SAVER			0
#define BALANCED			1
#define TURBO				2

#define HOTPLUG_PERCORE			1
#define HOTPLUG_SCHED			2

#define DEFAULT_CPU_LOAD_THRESHOLD	(80)
#define MIN_CPU_LOAD_THRESHOLD		(10)

#define HOTPLUG_ENABLED			(0)
#define DEFAULT_HOTPLUG_STYLE		HOTPLUG_SCHED
#define DEFAULT_SCHED_MODE		BALANCED

#define DEF_SAMPLING_MS			(50)
#define MIN_SAMLING_MS			(10)
#define MIN_CPU_UP_TIME			(750)

static bool isSuspended = false;

extern int sched_set_boost(int enable);
static int suspend_cpu_num = 2, resume_cpu_num = (NR_CPUS -1);
static int endurance_level = 0;
static int core_limit = NR_CPUS;

static int now[8], last_time[8];

static int sampling_time = DEF_SAMPLING_MS;
static int load_threshold = DEFAULT_CPU_LOAD_THRESHOLD;

struct cpufreq_policy old_policy[NR_CPUS];

static int tplug_hp_style = DEFAULT_HOTPLUG_STYLE;
static int tplug_hp_enabled = HOTPLUG_ENABLED;
static int tplug_sched_mode = DEFAULT_SCHED_MODE;

static struct workqueue_struct *tplug_wq;
static struct delayed_work tplug_work;

static struct workqueue_struct *tplug_resume_wq;
static struct delayed_work tplug_resume_work;

static unsigned int last_load[8] = { 0 };

struct cpu_load_data {
	u64 prev_cpu_idle;
	u64 prev_cpu_wall;
	unsigned int avg_load_maxfreq;
	unsigned int cur_load_maxfreq;
	unsigned int samples;
	unsigned int window_size;
	cpumask_var_t related_cpus;
};

static DEFINE_PER_CPU(struct cpu_load_data, cpuload);


/* Two Endurance Levels for Octa Cores,
 * Two for Quad Cores and
 * One for Dual
 */
static inline void offline_cpus(void)
{
	unsigned int cpu;
	switch(endurance_level) {
		case 1:
			if(suspend_cpu_num > NR_CPUS / 2 )
				suspend_cpu_num = NR_CPUS / 2;
			break;
		case 2:
			if( NR_CPUS >=4 && suspend_cpu_num > NR_CPUS / 4)
				suspend_cpu_num = NR_CPUS / 4;
			break;
		default:
			break;
	}
	for(cpu = NR_CPUS - 1; cpu > (suspend_cpu_num - 1); cpu--) {
		if (cpu_online(cpu))
			cpu_down(cpu);
	}
	pr_info("%s: %d cpus were offlined\n",
			THUNDERPLUG, (NR_CPUS - suspend_cpu_num));
}

static inline void cpus_online_all(void)
{
	unsigned int cpu;
	switch(endurance_level) {
		case 1:
			if (resume_cpu_num > (NR_CPUS / 2) - 1 ||
					resume_cpu_num == 1)
				resume_cpu_num = ((NR_CPUS / 2) - 1);
			break;
		case 2:
			if (NR_CPUS >= 4 && resume_cpu_num >
					((NR_CPUS / 4) - 1))
				resume_cpu_num = ((NR_CPUS / 4) - 1);
			break;
		case 0:
			resume_cpu_num = (NR_CPUS - 1);
			break;
		default:
			break;
	}

	if (DEBUG)
		pr_info("%s: resume_cpu_num = %d\n",THUNDERPLUG,
				resume_cpu_num);

	for (cpu = 1; cpu <= resume_cpu_num; cpu++) {
		if (cpu_is_offline(cpu))
			cpu_up(cpu);
	}

	pr_info("%s: all cpus were onlined\n", THUNDERPLUG);
}

static ssize_t thunderplug_suspend_cpus_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%d", suspend_cpu_num);
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
		suspend_cpu_num = val;

	return count;
}

static ssize_t thunderplug_endurance_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%d", endurance_level);
}

static ssize_t __ref thunderplug_endurance_store(struct kobject *kobj,
			struct kobj_attribute *attr,
			const char *buf, size_t count)
{
	int val;

	sscanf(buf, "%d", &val);

	if ((tplug_hp_style == 1) || (tplug_hp_enabled)) {

		switch(val) {
			case 0:
			case 1:
			case 2:
				if (endurance_level != val &&
						!(endurance_level > 1 &&
						NR_CPUS < 4)) {
					endurance_level = val;
					offline_cpus();
					cpus_online_all();
				}
				break;
			default:
				pr_info("%s: invalid endurance level\n",
					THUNDERPLUG);
				break;
		}
	} else
		pr_info("%s: per-core hotplug style is disabled,\
				ignoring endurance mode values\n",
				THUNDERPLUG);

	return count;
}

static ssize_t thunderplug_sampling_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%d", sampling_time);
}

static ssize_t __ref thunderplug_sampling_store(struct kobject *kobj,
			struct kobj_attribute *attr,
			const char *buf, size_t count)
{
	int val;

	sscanf(buf, "%d", &val);

	if (val > MIN_SAMLING_MS)
		sampling_time = val;

	return count;
}

static ssize_t thunderplug_load_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%d", load_threshold);
}

static ssize_t __ref thunderplug_load_store(struct kobject *kobj,
			struct kobj_attribute *attr,
			const char *buf, size_t count)
{
	int val;

	sscanf(buf, "%d", &val);

	if (val > 10)
		load_threshold = val;

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

static void thunderplug_suspend(void)
{
	offline_cpus();
	pr_info("%s: suspend\n", THUNDERPLUG);
}

static void __ref thunderplug_resume(void)
{
	cpus_online_all();
	pr_info("%s: resume\n", THUNDERPLUG);
}

static void __cpuinit tplug_resume_work_fn(struct work_struct *work)
{
	thunderplug_resume();
}

static void __cpuinit tplug_work_fn(struct work_struct *work)
{
	int i;
	unsigned int load[8], avg_load[8];

	switch(endurance_level) {
	case 0:
		core_limit = NR_CPUS;
		break;
	case 1:
		core_limit = NR_CPUS / 2;
		break;
	case 2:
		core_limit = NR_CPUS / 4;
		break;
	default:
		core_limit = NR_CPUS;
		break;
	}

	for (i = 0 ; i < core_limit; i++) {
		if (cpu_online(i))
			load[i] = get_curr_load(i);
		else
			load[i] = 0;

		avg_load[i] = ((int) load[i] + (int) last_load[i]) / 2;
		last_load[i] = load[i];
	}

	for (i = 0 ; i < core_limit; i++) {
		if (cpu_online(i) && avg_load[i] >
				load_threshold && cpu_is_offline(i + 1)) {
			if (DEBUG)
				pr_info("%s : bringing back cpu%d\n",
					THUNDERPLUG,i);
			if (!((i + 1) > 7)) {
				last_time[i + 1] = ktime_to_ms(ktime_get());
				cpu_up(i + 1);
			}
		} else if (cpu_online(i) && avg_load[i] <
				load_threshold && cpu_online(i + 1)) {
			if (DEBUG)
				pr_info("%s : offlining cpu%d\n",
					THUNDERPLUG,i);
			if (!(i + 1) == 0) {
				now[i + 1] = ktime_to_ms(ktime_get());
				if ((now[i + 1] - last_time[i + 1]) >
						MIN_CPU_UP_TIME)
					cpu_down(i + 1);
			}
		}
	}

	if ((tplug_hp_style == 1 && !isSuspended) ||
			(tplug_hp_enabled != 0 && !isSuspended)) {
		queue_delayed_work_on(0, tplug_wq, &tplug_work,
			msecs_to_jiffies(sampling_time));
	} else {
		if (!isSuspended)
			cpus_online_all();
		else
			thunderplug_suspend();
	}
}

#ifdef CONFIG_STATE_NOTIFIER
static void tplug_es_suspend_work(struct notifier_block *p)
{
	isSuspended = true;
	pr_info("thunderplug : suspend called\n");
}

static void tplug_es_resume_work(struct notifier_block *p)
{
	isSuspended = false;

	if ((tplug_hp_style == 1) || (tplug_hp_enabled))
		queue_delayed_work_on(0, tplug_wq, &tplug_work,
				msecs_to_jiffies(sampling_time));
	else
		queue_delayed_work_on(0, tplug_resume_wq, &tplug_resume_work,
				msecs_to_jiffies(10));

	pr_info("thunderplug : resume called\n");
}

static int state_notifier_callback(struct notifier_block *this,
				unsigned long event, void *data)
{
	switch (event) {
		case STATE_NOTIFIER_ACTIVE:
			tplug_es_resume_work(this);
			break;
		case STATE_NOTIFIER_SUSPEND:
			tplug_es_suspend_work(this);
			break;
		default:
			break;
	}
	return NOTIFY_OK;
}
#endif

/* Thunderplug load balancer */

static void set_sched_profile(int mode)
{
	switch(mode) {
		case 1:
			/* Balanced */
			sched_set_boost(BOOST_DISABLED);
			break;
		case 2:
			/* Turbo */
			sched_set_boost(BOOST_ENABLED);
			break;
		default:
			pr_info("%s: Invalid mode\n", THUNDERPLUG);
			break;
	}
}

static ssize_t thunderplug_sched_mode_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%d", tplug_sched_mode);
}

static ssize_t __ref thunderplug_sched_mode_store(struct kobject *kobj,
			struct kobj_attribute *attr,
			const char *buf, size_t count)
{
	int val;

	sscanf(buf, "%d", &val);

	set_sched_profile(val);
	tplug_sched_mode = val;

	return count;
}

static ssize_t thunderplug_hp_style_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%d", tplug_hp_style);
}

static ssize_t __ref thunderplug_hp_style_store(struct kobject *kobj,
			struct kobj_attribute *attr,
			const char *buf, size_t count)
{
	int val, last_val;

	sscanf(buf, "%d", &val);

	last_val = tplug_hp_style;
	switch(val) {
		case HOTPLUG_PERCORE:
		case HOTPLUG_SCHED:
			tplug_hp_style = val;
			break;
		default:
			pr_info("%s : invalid choice\n", THUNDERPLUG);
			break;
	}

	if (tplug_hp_style == HOTPLUG_PERCORE && tplug_hp_style != last_val) {
		pr_info("%s: Switching to Per-core hotplug model\n",
					THUNDERPLUG);
		sched_set_boost(BOOST_DISABLED);
		queue_delayed_work_on(0, tplug_wq, &tplug_work,
					msecs_to_jiffies(sampling_time));
	} else if (tplug_hp_style == 2) {
		pr_info("%s: Switching to sched based hotplug model\n",
					THUNDERPLUG);
		set_sched_profile(tplug_sched_mode);
	}

	return count;
}

static struct kobj_attribute thunderplug_hp_style_attribute =
       __ATTR(hotplug_style,
               0666,
               thunderplug_hp_style_show, thunderplug_hp_style_store);

static struct kobj_attribute thunderplug_mode_attribute =
       __ATTR(sched_mode,
               0666,
               thunderplug_sched_mode_show, thunderplug_sched_mode_store);

static ssize_t thunderplug_hp_enabled_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%d", tplug_hp_enabled);
}

static ssize_t __ref thunderplug_hp_enabled_store(struct kobject *kobj,
			struct kobj_attribute *attr,
			const char *buf, size_t count)
{
	int val, last_val;

	sscanf(buf, "%d", &val);

	last_val = tplug_hp_enabled;
	switch(val) {
		case 0:
		case 1:
			tplug_hp_enabled = val;
			break;
		default:
			pr_info("%s : invalid choice\n", THUNDERPLUG);
			break;
	}

	if (tplug_hp_enabled == 1 && tplug_hp_enabled != last_val)
		queue_delayed_work_on(0, tplug_wq, &tplug_work,
					msecs_to_jiffies(sampling_time));

	return count;
}

static struct kobj_attribute thunderplug_hp_enabled_attribute =
       __ATTR(hotplug_enabled,
               0666,
               thunderplug_hp_enabled_show, thunderplug_hp_enabled_store);


static ssize_t thunderplug_ver_show(struct kobject *kobj,
			struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "ThunderPlug %u.%u", DRIVER_VERSION,
			DRIVER_SUBVER);
}

static struct kobj_attribute thunderplug_ver_attribute =
	__ATTR(version,
		0444, thunderplug_ver_show, NULL);

static struct kobj_attribute thunderplug_suspend_cpus_attribute =
	__ATTR(suspend_cpus,
		0666, thunderplug_suspend_cpus_show,
		thunderplug_suspend_cpus_store);

static struct kobj_attribute thunderplug_endurance_attribute =
	__ATTR(endurance_level,
		0666, thunderplug_endurance_show,
		thunderplug_endurance_store);

static struct kobj_attribute thunderplug_sampling_attribute =
	__ATTR(sampling_rate,
		0666, thunderplug_sampling_show,
		thunderplug_sampling_store);

static struct kobj_attribute thunderplug_load_attribute =
	__ATTR(load_threshold,
		0666, thunderplug_load_show,
		thunderplug_load_store);

static struct attribute *thunderplug_attrs[] = {
	&thunderplug_ver_attribute.attr,
	&thunderplug_suspend_cpus_attribute.attr,
	&thunderplug_endurance_attribute.attr,
	&thunderplug_sampling_attribute.attr,
	&thunderplug_load_attribute.attr,
	&thunderplug_mode_attribute.attr,
	&thunderplug_hp_style_attribute.attr,
	&thunderplug_hp_enabled_attribute.attr,
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

#ifdef CONFIG_STATE_NOTIFIER
	thunder_state_notif.notifier_call = state_notifier_callback;
	if (state_register_client(&thunder_state_notif))
		pr_err("%s: Failed to register State notifier callback\n",
			__func__);
#endif
	tplug_wq = alloc_workqueue("tplug",
			WQ_HIGHPRI | WQ_UNBOUND, 1);

	tplug_resume_wq = alloc_workqueue("tplug_resume",
			WQ_HIGHPRI | WQ_UNBOUND, 1);

	INIT_DELAYED_WORK(&tplug_work, tplug_work_fn);
	INIT_DELAYED_WORK(&tplug_resume_work, tplug_resume_work_fn);
	queue_delayed_work_on(0, tplug_wq, &tplug_work,
				msecs_to_jiffies(10));

	pr_info("%s: init\n", THUNDERPLUG);

	return ret;
}

MODULE_LICENSE("GPL and additional rights");
MODULE_AUTHOR("Varun Chitre <varun.chitre15@gmail.com>");
MODULE_DESCRIPTION("Hotplug driver for ARM SoCs");
late_initcall(thunderplug_init);
