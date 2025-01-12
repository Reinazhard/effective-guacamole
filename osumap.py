# This script generates download URLs for osu! beatmap packs and optionally downloads them using aria2c.
# It detects the appropriate file format (.zip or .7z) for each beatmap pack and writes the URLs to a file.
# The user can choose to immediately start downloading the packs with aria2c or save the file for manual use later.
# Make sure to install aiohttp python module

import asyncio
import aiohttp
import subprocess
from aiohttp import ClientTimeout

async def detect_file_format(session, number):
    # Newer format
    base_url_new = f"https://packs.ppy.sh/S{number}%20-%20osu%21%20Beatmap%20Pack%20%23{number}"
    # Older format
    base_url_old = f"https://packs.ppy.sh/S{number}%20-%20Beatmap%20Pack%20%23{number}"

    for base_url in [base_url_new, base_url_old]:
        for ext in [".zip", ".7z"]:
            url = base_url + ext
            for attempt in range(3):  # Retry logic
                try:
                    async with session.head(url) as response:
                        if response.status == 200:
                            return url
                except asyncio.TimeoutError:
                    print(f"Timeout for {url} (attempt {attempt + 1}/3)")
                except aiohttp.ClientError as e:
                    print(f"Error for {url}: {e} (attempt {attempt + 1}/3)")
                await asyncio.sleep(1)  # Backoff between retries
    return None

async def fetch_urls(start, end):
    urls = {}

    async def fetch_url(session, number):
        url = await detect_file_format(session, number)
        urls[number] = url
        if url:
            print(f"Detected: {url}")
        else:
            print(f"Warning: No file found for S{number}")

    timeout = ClientTimeout(total=30)  # Set global timeout for all requests
    connector = aiohttp.TCPConnector(limit=20)  # Limit concurrent connections
    async with aiohttp.ClientSession(timeout=timeout, connector=connector) as session:
        tasks = [fetch_url(session, number) for number in range(start, end + 1)]
        await asyncio.gather(*tasks)

    return urls

def save_urls_to_file(urls, output_file):
    with open(output_file, "w") as file:
        for number, url in urls.items():
            if url:
                file.write(url + "\n")
    print(f"URLs successfully saved to {output_file}.")

def generate_and_download_osu_maps():
    try:
        start = int(input("Enter the starting beatmap pack number: ").strip())
        end = int(input("Enter the ending beatmap pack number: ").strip())
    except ValueError:
        print("Error: Please enter valid integers for the range.")
        return

    output_file = "osu_map_downloads.txt"

    # Run the async fetcher
    urls = asyncio.run(fetch_urls(start, end))

    # Save URLs to file
    save_urls_to_file(urls, output_file)

    # Optionally start aria2c
    start_aria2c = input("Do you want to start aria2c to download the maps? (yes/no): ").strip().lower()
    if start_aria2c in ["yes", "y"]:
        print("Starting aria2c...")
        subprocess.run(["aria2c", "-i", output_file])
    else:
        print("aria2c was not started. You can use the file later to download manually.")

# Run the script
generate_and_download_osu_maps()
