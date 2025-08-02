import board
import busio
from adafruit_pn532.i2c import PN532_I2C
import urllib.parse
import requests
import time

# Set up I2C bus and connect to the PN532 NFC module
i2c = busio.I2C(board.SCL, board.SDA)
pn532 = PN532_I2C(i2c, debug=False)
pn532.SAM_configuration()  # Configure for reading NFC tags

print("Scan a Plexamp NFC tag...")

# For debouncing repeated scans of the same tag
last_uid = None
last_scan_time = 0
debounce_seconds = 5  # Minimum time in seconds between repeated scans of same tag

while True:
    # Wait for tag detection
    uid = pn532.read_passive_target(timeout=0.5)

    if uid:
        uid_str = ' '.join([hex(i) for i in uid])
        now = time.time()

        # Skip if it's the same tag and scanned too soon
        if uid == last_uid and (now - last_scan_time) < debounce_seconds:
            continue

        last_uid = uid
        last_scan_time = now

        print("Tag UID:", uid_str)

        # Read all relevant blocks from the tag to extract the NDEF record
        tag_data = bytearray()
        for block in range(4, 50):  # Extended range to capture longer NDEF URIs
            try:
                block_data = pn532.ntag2xx_read_block(block)
                if block_data:
                    tag_data += block_data
            except Exception:
                continue  # Ignore unreadable blocks

        tag_data = tag_data.rstrip(b'\x00')  # Strip trailing nulls

        try:
            # Look for URI record (NDEF type 0x55)
            uri_tnf_index = tag_data.find(b'\x55')
            if uri_tnf_index != -1 and uri_tnf_index + 2 < len(tag_data):
                prefix_code = tag_data[uri_tnf_index + 1]
                raw_uri_bytes = tag_data[uri_tnf_index + 2:]

                # NDEF prefix mapping (RFC 3986 short forms)
                prefix_map = {
                    0x00: "", 0x01: "http://www.", 0x02: "https://www.",
                    0x03: "http://", 0x04: "https://"
                }
                prefix = prefix_map.get(prefix_code, "")
                print(f"🧪 Raw URI bytes (after prefix byte): {raw_uri_bytes}")

                # Combine prefix and URI body
                uri_path = raw_uri_bytes.decode("utf-8", errors="ignore")
                full_url = prefix + uri_path

                # Sanitize: remove trailing junk bytes like \xfe or stray whitespace
                full_url = full_url.rstrip(" \n\r\x00\xfe\t")

                print(f"\n🎯 Parsed Tag URL:\n{full_url}")
                print(f"🔎 Decoded URL length: {len(full_url)} chars")

                # Basic validation to skip clearly malformed or incomplete links
                if (
                    len(full_url) < 100
                    or "metadata" not in full_url
                    or not full_url.startswith("https://listen.plex.tv/player/playback/playMedia?uri=")
                ):
                    print("⚠️ Truncated or malformed URL — skipping.")
                    continue

                # Replace remote base URL with local headless Plexamp endpoint
                local_url = full_url.replace("https://listen.plex.tv", "http://localhost:32500")
                local_url = local_url.replace("http://listen.plex.tv", "http://localhost:32500")
                print("🔁 Converted to local:", local_url)

                try:
                    # Send request to trigger Plexamp playback
                    response = requests.get(local_url)
                    if response.ok:
                        print("✅ Playback triggered!")
                    else:
                        print(f"⚠️ Error triggering playback: {response.status_code}")
                except Exception as e:
                    print("❌ Failed to connect to Plexamp headless:", e)
            else:
                print("⚠️ No valid URI NDEF record found.")

        except Exception as e:
            print("❌ Decode error:", e)
