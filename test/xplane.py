import socket
import struct
import time
import threading

# X-Plane UDP 默认端口
XPLANE_IP = "127.0.0.1"
XPLANE_PORT = 49001
LOCAL_PORT = 19191

class XPlaneClient:
    def __init__(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        # 允许端口重用，方便调试
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind((XPLANE_IP, LOCAL_PORT))
        self.sock.settimeout(1.0)
        self.running = True
        self.data_values = {}

    def create_rref_packet(self, dref_name, frequency, index):
        """
        构造 RREF 数据包
        RREF\0 (5 bytes) + freq (4 bytes) + index (4 bytes) + dref_name (400 bytes)
        """
        header = b'RREF\x00'
        freq_bytes = struct.pack('<i', frequency)
        index_bytes = struct.pack('<i', index)
        dref_bytes = dref_name.encode('utf-8').ljust(400, b'\x00')
        return header + freq_bytes + index_bytes + dref_bytes

    def subscribe(self, dref_name, index, frequency=5):
        """订阅一个 Dataref"""
        packet = self.create_rref_packet(dref_name, frequency, index)
        self.sock.sendto(packet, (XPLANE_IP, XPLANE_PORT))
        print(f"已发送订阅请求: {dref_name} (索引: {index})")

    def receive_loop(self):
        """接收数据循环"""
        print(f"开始在端口 {LOCAL_PORT} 监听 X-Plane 数据...")
        last_subscribe_time = 0

        # 用户要求的基准路径
        lights_dref = "sim/cockpit2/switches/generic_lights_switch"
        gear_dref = "sim/flightmodel2/gear/deploy_ratio"

        # 缓存上次的值，用于检测变化
        last_values = {}

        while self.running:
            # 每 10 秒重发一次订阅请求
            current_time = time.time()
            if current_time - last_subscribe_time > 10:
                print(f"正在发送订阅请求...")
                # 订阅灯光开关 (索引 0-100)
                for i in range(101):
                    self.subscribe(f"{lights_dref}[{i}]", i, frequency=5)
                # 订阅起落架展开比例 (索引 200-209, 对应起落架 0-9)
                for i in range(10):
                    self.subscribe(f"{gear_dref}[{i}]", 200 + i, frequency=5)

                last_subscribe_time = current_time

            try:
                data, addr = self.sock.recvfrom(4096)
                if data.startswith(b'RREF'):
                    n_values = (len(data) - 5) // 8
                    for i in range(n_values):
                        offset = 5 + i * 8
                        idx = struct.unpack('<i', data[offset:offset+4])[0]
                        val = struct.unpack('<f', data[offset+4:offset+8])[0]

                        # 处理灯光数据 (0-100)
                        if 0 <= idx <= 100:
                            is_on = val > 0.5
                            if idx not in last_values or last_values[idx] != is_on:
                                state_str = "开启" if is_on else "关闭"
                                print(f"[灯光更新] 索引 {idx}: {state_str} (原始值: {val:.2f})")
                                last_values[idx] = is_on

                        # 处理起落架数据 (200-209)
                        elif 200 <= idx <= 209:
                            gear_idx = idx - 200
                            # 仅在值发生显著变化时输出 (变化超过 0.01)
                            if idx not in last_values or abs(last_values[idx] - val) > 0.01:
                                print(f"[起落架更新] 起落架 {gear_idx}: 展开度 {val*100:.1f}%")
                                last_values[idx] = val

                        self.data_values[idx] = val

            except socket.timeout:
                continue
            except Exception as e:
                print(f"接收出错: {e}")
                break

    def stop(self):
        self.running = False
        self.sock.close()

if __name__ == "__main__":
    client = XPlaneClient()
    try:
        client.receive_loop()
    except KeyboardInterrupt:
        print("\n脚本已停止")
        client.stop()
