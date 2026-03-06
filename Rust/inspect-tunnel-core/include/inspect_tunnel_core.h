#ifndef INSPECT_TUNNEL_CORE_H
#define INSPECT_TUNNEL_CORE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct InspectTunnelCoreStats {
    uint64_t tx_packets;
    uint64_t tx_bytes;
    uint64_t rx_packets;
    uint64_t rx_bytes;
} InspectTunnelCoreStats;

const char *inspect_tunnel_core_version(void);
const char *inspect_tunnel_core_last_error_message(void);

int32_t inspect_tunnel_core_set_log_file(const char *path);
int32_t inspect_tunnel_core_set_tun_fd(int32_t fd);
int32_t inspect_tunnel_core_start(const char *config_json);
int32_t inspect_tunnel_core_start_live_loop(void);
void inspect_tunnel_core_stop(void);
int32_t inspect_tunnel_core_get_stats(InspectTunnelCoreStats *out_stats);
const char *inspect_tunnel_core_drain_observations_json(void);

#ifdef __cplusplus
}
#endif

#endif
