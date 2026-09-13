#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>

static volatile int g_running = 1;

static void handle_signal(int sig) {
    (void)sig;
    g_running = 0;
}

static void log_daemon(const char *msg) {
    FILE *f = fopen("/var/mobile/Downloads/onerlay_daemon.log", "a");
    if (f) {
        time_t now = time(NULL);
        struct tm *tm_info = localtime(&now);
        char time_buf[32];
        strftime(time_buf, sizeof(time_buf), "%Y-%m-%d %H:%M:%S", tm_info);
        fprintf(f, "[%s] %s\n", time_buf, msg);
        fclose(f);
    }
}

int main(int argc, char *argv[]) {
    (void)argc; (void)argv;
    signal(SIGTERM, handle_signal);
    signal(SIGINT, handle_signal);
    
    char start_msg[128];
    snprintf(start_msg, sizeof(start_msg), "onerlaydaemon started (PID: %d)", getpid());
    log_daemon(start_msg);
    
    int heartbeat_count = 0;
    while (g_running) {
        sleep(10);
        heartbeat_count++;
        if (heartbeat_count % 6 == 0) { // Every 60s
            char hb_msg[64];
            snprintf(hb_msg, sizeof(hb_msg), "onerlaydaemon heartbeat #%d", heartbeat_count);
            log_daemon(hb_msg);
        }
    }
    
    log_daemon("onerlaydaemon stopped gracefully");
    return 0;
}
