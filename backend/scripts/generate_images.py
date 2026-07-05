import asyncio
import json
import sys
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.app.core.config import get_settings

SEED_PATH = ROOT / "backend" / "seed" / "products.json"


async def generate_images():
    settings = get_settings()
    access_key = settings.unsplash_access_key
    if not access_key:
        print("Missing HUAL_UNSPLASH_ACCESS_KEY in .env")
        sys.exit(1)

    with SEED_PATH.open("r", encoding="utf-8") as handle:
        products = json.load(handle)

    print(f"Loaded {len(products)} products. Starting Unsplash image generation...")

    async with httpx.AsyncClient(timeout=10.0) as client:
        for i, product in enumerate(products):
            query = " ".join(product.get("searchTokens", []))
            if not query:
                query = product["name"]

            try:
                response = await client.get(
                    f"{settings.unsplash_api_base_url.rstrip('/')}/search/photos",
                    params={
                        "query": query,
                        "per_page": 1,
                        "orientation": "portrait",
                        "content_filter": "high"
                    },
                    headers={
                        "Authorization": f"Client-ID {access_key}",
                        "Accept-Version": "v1"
                    },
                )
                
                # Check for rate limit
                remaining = response.headers.get("x-ratelimit-remaining")
                if response.status_code == 403 and remaining == "0":
                    print("Unsplash quota exhausted!")
                    break
                    
                response.raise_for_status()
                data = response.json()
                
                results = data.get("results", [])
                if results and len(results) > 0:
                    image_url = results[0]["urls"]["regular"]
                    product["imageUrls"] = [image_url]
                    print(f"[{i+1}/{len(products)}] Found image for {product['id']}: {query}")
                else:
                    print(f"[{i+1}/{len(products)}] No image found for {product['id']}: {query}")
                    
                # Small sleep to be nice to the API
                await asyncio.sleep(0.5)

            except Exception as e:
                print(f"[{i+1}/{len(products)}] Failed for {product['id']}: {e}")

    with SEED_PATH.open("w", encoding="utf-8") as handle:
        json.dump(products, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
        
    print("Successfully updated products.json with image URLs.")

if __name__ == "__main__":
    asyncio.run(generate_images())
