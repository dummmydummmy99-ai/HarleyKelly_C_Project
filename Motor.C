/****************************************************************************
* Title                 :   Motor Controller Process (Process C)
* Filename              :   motor_ctrl.c
* Author                :   Harley Kelly
* Origin Date           :   14/11/2025
* Version               :   1.0.3
* Compiler              :   Microchip C30 v3.30c
* Target                :   Cross-Platform
* Notes                 :   Executes motor commands from Process B
*****************************************************************************/
/*************** INTERFACE CHANGE LIST **************************************
*
*    Date        Software Version    Initials   Description 
*  28/11/2025       1.0.3             HK       Added shared log mutex
*  21/11/2025       1.0.2             HK       Implemented B → C → B command chain
*  14/11/2025       1.0.1             HK       Initial motor controller stub
*
*****************************************************************************/

#include <stdio.h>
#include <stdlib.h>

#ifdef _WIN32
#include <windows.h>
#define sleep_ms(ms) Sleep(ms)
#else
#include <unistd.h>
#define sleep_ms(ms) usleep(ms * 1000)
#endif

#define CMD_FILE        "motor_cmd.txt"
#define CMD_READY_FLAG  "cmd_ready.flag"
#define CMD_ACK_FLAG    "cmd_ack.flag"

#define SYSTEM_LOG      "system_log.txt"
#define LOG_LOCK        "log.lock"

#define POLL_INTERVAL_MS 100

static int file_exists(const char *filename)
{
    FILE *f = fopen(filename, "r");
    if (f) { fclose(f); return 1; }
    return 0;
}

static void create_file(const char *filename)
{
    FILE *f = fopen(filename, "w");
    if (f) fclose(f);
}

static void acquire_log_lock(void)
{
    while (file_exists(LOG_LOCK))
        sleep_ms(10);
    create_file(LOG_LOCK);
}

static void release_log_lock(void)
{
    remove(LOG_LOCK);
}

static void write_log(const char *msg)
{
    acquire_log_lock();
    FILE *log = fopen(SYSTEM_LOG, "a");
    if (log) {
        fprintf(log, "[C] %s\n", msg);
        fclose(log);
    }
    release_log_lock();
}

int main()
{
    char buf[256];
    write_log("Process C started.");

    while (1)
    {
        while (!file_exists(CMD_READY_FLAG))
            sleep_ms(POLL_INTERVAL_MS);

        remove(CMD_READY_FLAG);
        write_log("Received motor command from B.");

        FILE *fp = fopen(CMD_FILE, "r");
        if (!fp) { write_log("ERROR: Could not open motor_cmd.txt"); continue; }
        while (fgets(buf, sizeof(buf), fp)) {}
        fclose(fp);

        sleep_ms(500);

        write_log("Motor command executed.");
        create_file(CMD_ACK_FLAG);

        sleep_ms(100);
    }

    return 0;
}
