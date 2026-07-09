use std::net::IpAddr;

use local_ip_address::{list_afinet_netifas, local_ip};

/// Interfaces virtuais que não servem para acesso LAN (VPN, loopback de áudio, etc.).
fn is_virtual_interface(name: &str) -> bool {
    let n = name.to_lowercase();
    n.starts_with("feth")
        || n.starts_with("utun")
        || n.starts_with("bridge")
        || n.starts_with("awdl")
        || n.starts_with("llw")
        || n.starts_with("lo")
        || n.starts_with("gif")
        || n.starts_with("stf")
        || n.starts_with("pktap")
        || n.starts_with("anpi")
        || n.starts_with("ap")
}

fn interface_score(name: &str, ip: &IpAddr) -> i32 {
    let IpAddr::V4(ipv4) = ip else {
        return -1;
    };
    if ipv4.is_loopback() || is_virtual_interface(name) {
        return -1;
    }

    let mut score = 0;

    if name == "en0" {
        score += 100;
    } else if name.starts_with("en") {
        score += 80;
    } else if name.starts_with("eth") || name.starts_with("wlan") {
        score += 70;
    } else {
        score += 10;
    }

    let [a, b, _, _] = ipv4.octets();
    if a == 192 && b == 168 {
        score += 50;
    } else if a == 172 && (16..=31).contains(&b) {
        score += 40;
    } else if a == 10 {
        score += 20;
    }

    score
}

fn pick_lan_ip() -> Option<IpAddr> {
    let ifas = list_afinet_netifas().ok()?;

    ifas.iter()
        .filter(|(_, ip)| matches!(ip, IpAddr::V4(v) if !v.is_loopback()))
        .map(|(name, ip)| (name.as_str(), ip, interface_score(name, ip)))
        .filter(|(_, _, score)| *score >= 0)
        .max_by_key(|(_, _, score)| *score)
        .map(|(_, ip, _)| *ip)
}

/// Retorna o IP local preferencial (Wi-Fi/Ethernet) para montar a URL da sala.
#[tauri::command]
pub fn get_local_ip() -> Result<String, String> {
    if let Some(ip) = pick_lan_ip() {
        return Ok(ip.to_string());
    }

    local_ip()
        .map(|ip| ip.to_string())
        .map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn prefere_en0_lan_sobre_interface_virtual() {
        assert!(interface_score("en0", &"192.168.3.105".parse().unwrap()) > 0);
        assert_eq!(
            interface_score("feth3003", &"10.147.13.34".parse().unwrap()),
            -1
        );
    }
}
