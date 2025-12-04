/****************************************************************************
* Title                 :   Navigation Planner Process (Process B)
* Filename              :   nav_planner.c
* Author                :   Harley Kelly
* Origin Date           :   14/11/2025
* Version               :   1.0.3
* Compiler              :   Microchip C30 v3.30c
* Target                :   Cross-Platform
* Notes                 :   Reads LIDAR data from Process A, sends motor commands to Process C
*****************************************************************************/

#include <stdio.h>
#include <stdlib.h>

#ifdef _WIN32
#include <windows.h>
#define sleep_ms(ms) Sleep(ms)
#else
#include <unistd.h>
#define sleep_ms(ms) usleep(ms*1000)
#endif

#define DATA_FILE "lidar_data.txt"
#define READY_FLAG "data_ready.flag"
#define ACK_FLAG "ack_from_B.flag"
#define CMD_FILE "motor_cmd.txt"
#define CMD_READY "cmd_ready.flag"
#define CMD_ACK "cmd_ack.flag"
#define SYSTEM_LOG "system_log.txt"
#define LOG_LOCK "log.lock"

int file_exists(const char *filename) {
    FILE *f = fopen(filename,"r");
    if(f){ fclose(f); return 1; } return 0;
}

void create_file(const char *filename) {
    FILE *f = fopen(filename,"w");
    if(f) fclose(f);
    else fprintf(stderr,"Error creating file %s\n",filename);
}

//--- Mutex log functions ---
static void acquire_log_lock(void) { while(file_exists(LOG_LOCK)) sleep_ms(10); create_file(LOG_LOCK); }
static void release_log_lock(void) { remove(LOG_LOCK); }
static void write_log(const char *msg) {
    acquire_log_lock();
    FILE *log = fopen(SYSTEM_LOG,"a");
    if(log){ fprintf(log,"[Nav_Planner] %s\n",msg); fclose(log);}
    release_log_lock();
}

int main() {
    char line[256];
    printf("Process B (Nav_Planner) started.\n");
    write_log("Process started.");

    remove(ACK_FLAG);
    remove(CMD_READY);
    remove(CMD_ACK);

    while(1) {
        //--- Wait for Process A ---
        while(!file_exists(READY_FLAG)) sleep_ms(100);
        remove(READY_FLAG);

        FILE *f = fopen(DATA_FILE,"r");
        if(!f){ sleep_ms(1000); continue; }

        int packet_id=0;
        while(fgets(line,sizeof(line),f)){
            if(sscanf(line,"packet_id: %d",&packet_id)==1) break;
        }
        fclose(f);

        //--- Send ACK to A ---
        create_file(ACK_FLAG);

        //--- Create motor command ---
        FILE *cmd = fopen(CMD_FILE,"w");
        if(cmd){
            fprintf(cmd,"command_id: %d\n", packet_id);
            fclose(cmd);
        }
        create_file(CMD_READY);

        printf("[Nav_Planner] Received packet %d, sent motor command.\n", packet_id);
        write_log("Processed packet and sent motor command.");

        //--- Wait for Motor Ctrl ACK ---
        while(!file_exists(CMD_ACK)) sleep_ms(100);
        remove(CMD_ACK);
        write_log("Received ACK from Process C.");

        sleep_ms(200);
    }
    return 0;
}
