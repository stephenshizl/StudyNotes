#TODO 收集时钟信息
# 捕捉时钟和调节器转储
adb shell
#mount -t debugfs none /sys/kernel/debug
sleep 10 && while true;
do
    echo "================debug/clk/=====================";
    cat /proc/uptime;
    cd /sys/kernel/debug/clk;
    for i in *;   # 遍历当前目录所有文件
    do
        # 检测文件是否为目录
        if [ -d $i ]; then
            if [ "$(cat $i/enable)" == "1" ]; then
                if [ -e $i/measure ]; then
                    echo $i \=\> enable:`cat $i/enable` measure:`cat $i/measure`;
                else
                    echo $i \=\> enable:`cat $i/enable` rate:`cat $i/rate`;
                fi;
            fi;
        fi;
    done;

    # 适配器转存
    echo "=====================================";
    cd /sys/class/regulator;
    for i in *;
    do if [ -d $i ]; then
           if [ -e $i/state ]; then
               if [ "$(cat $i/state)" == "enabled" ]; then
                   if [ -e $i/microvolts ]; then
                       echo $i \=\> name:`cat $i/name` state:`cat $i/state` microvolt:`cat $i/microvolts`;
                   else
                       echo $i \=\> name:`cat $i/name` state:`cat $i/state` microvolt: N\/A;
                   fi;
               fi;
           fi;
       fi;
    done;
    sleep 2;
done > /sdcard/dumpclk.txt &
adb pull /sdcard/dumpclk.txt .

#TODO 采集唤醒锁信息
adb shell cat /sys/kernel/debug/wakeup_sources # 或者adb shelldumpsys power
sleep 60 && cat /d/wakeup_sources > /sdcard/wakelocks.txt&
cat ~/wakelocks.txt | awk '{print $1"\t\t\t\t\t\t"$6}'

#TODO 捕捉PowerTop和Top数据
sleep 3 && while true;
do echo "=======================================";
   cat /proc/uptime;
   top -m 25 -d 1 -n 1 -t;
   echo "---------------------------------------";
   /data/powertop -r -d -t 5
done > /sdcard/dumptop.txt &

adb pull /sdcard/dumptop.txt .

#TODO batterystats
# 分析battery历史状态
# 54s开始
# dumpsys教程
sudo adb shell dumpsys batterystats|tee bugreport-"$(date +%Y-%m-%d\ %R)"_con.log#
sudo adb shell sleep 5 && dumpsys batterystats --reset  #清空日志
sudo adb bugreport > bugreport-"$(date +%Y-%m-%d\ %R)"_changjin1.log

#TODO ftrace
# 1.链接USB
# 2.输入以下命令
adb root
adb remount
adb shell
cd /sys/kernel/debug/tracing
echo 0 > tracing_on; #关闭
echo 100000 > buffer_size_kb;#设置缓存区大小

echo "" > set_event #清空event设置
echo "" > trace #清空trace缓冲区
# 设置event
echo "power:cpu_idle power:cpu_frequency power:cpu_frequency_switch_start" >> set_event
echo "msm_low_power:* sched:sched_cpu_hotplug sched:sched_switch" >> set_event
echo "sched:sched_wakeup sched:sched_wakeup_new sched:sched_enq_deq_task" >> set_event
echo "power:clock_set_rate power:clock_enable power:clock_disable msm_bus:bus_update_request" >> set_event
echo "irq:*" >> set_event
echo "mdss:mdp_mixer_update mdss:mdp_sspp_change mdss:mdp_commit" >> set_event
echo "kgsl:kgsl_pwrlevel kgsl:kgsl_buslevel kgsl:kgsl_pwr_set_state" >> set_event
# 抓取trace的log
sleep 10 &&
    echo "0" > tracing_on && #关闭trace
    echo "" > trace && #清空trace缓冲区
                       #设置event
    echo "1" > tracing_on && #开启trace
    sleep 10 &&              #运行10s
    echo "0" > tracing_on && #关闭trace
    cat trace > /sdcard/trace.txt &

# 3.执行上述命令的10秒内断开usb，大约1分钟后链接USB，把Ftrace日志拉出来
adb pull /sdcard/trace.txt ~

#TODO