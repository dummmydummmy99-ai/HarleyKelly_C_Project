/****************************************************************************
* Title                 :   Navigation Planner Process (Process B)
* Filename              :   nav_planner.c
* Author                :   Harley Kelly
* Origin Date           :   14/11/2025
* Version               :   1.0.4
* Compiler              :   Microchip C30 v3.30c
* Target                :   Cross-Platform
* Notes                 :   Middle layer: A ↔ B ↔ C coordination
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

#define DATA_FILE       "lidar_data.txt"
#define READY_FLAG      "data_ready.flag"
#define ACK_FLAG        "ack.flag"

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
        fprintf(log, "[Nav_Planner] %s\n", msg);
        fclose(log);
    }
    release_log_lock();
}

int main()
{
    char buffer[256];
    write_log("Process started.");

    while (1)
    {
        // Wait for new LIDAR data
        while (!file_exists(READY_FLAG))
            sleep_ms(POLL_INTERVAL_MS);

        remove(READY_FLAG);

        FILE *fp = fopen(DATA_FILE, "r");
        if (!fp) { write_log("ERROR: Cannot open LIDAR file."); continue; }

        int packet_id = 0;
        fgets(buffer, sizeof(buffer), fp); // read first line
        sscanf(buffer, "packet_id: %d", &packet_id); // extract packet ID

        fclose(fp);

        create_file(ACK_FLAG); // send ACK to A

        // Generate motor command for C
        FILE *cmd = fopen(CMD_FILE, "w");
        if (cmd) {
            fprintf(cmd, "command_id: %d\n", packet_id);
            fprintf(cmd, "drive_speed: %.2f\n", 1.0);
            fprintf(cmd, "turn_angle: %.2f\n", 0.4);
            fclose(cmd);
        }
        create_file(CMD_READY_FLAG);

        printf("[Nav_Planner] Received packet %d, sent motor command.\n", packet_id);
        write_log("Processed packet and sent motor command.");

        // Wait for ACK from C
        while (!file_exists(CMD_ACK_FLAG))
            sleep_ms(POLL_INTERVAL_MS);

        remove(CMD_ACK_FLAG);
        write_log("Received ACK from Process C.");

        sleep_ms(200);
    }

    return 0;
}
