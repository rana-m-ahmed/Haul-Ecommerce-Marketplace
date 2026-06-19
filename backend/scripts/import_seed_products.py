from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.app.core.config import get_settings
from backend.app.core.firebase import initialize_firebase
from backend.app.services.catalog_repository import normalize_product


SEED_PATH = ROOT / "backend" / "seed" / "products.json"


def load_products() -> list[dict]:
    with SEED_PATH.open("r", encoding="utf-8") as handle:
        return [normalize_product(product) for product in json.load(handle)]


def import_products(dry_run: bool = False) -> int:
    products = load_products()
    if dry_run:
        for product in products[:3]:
            print(f"{product['id']}: {product['searchTokens']}")
        print(f"dry-run products={len(products)}")
        return len(products)

    settings = get_settings()
    initialize_firebase(settings)
    from firebase_admin import firestore

    client = firestore.client()
    batch = client.batch()
    for product in products:
        product_ref = client.collection("products").document(product["id"])
        batch.set(product_ref, product)
    batch.commit()
    print(f"imported products={len(products)}")
    return len(products)


def main() -> None:
    parser = argparse.ArgumentParser(description="Import Hual seed products into Firestore.")
    parser.add_argument("--dry-run", action="store_true", help="Generate tokens and print a sample without writing Firestore.")
    args = parser.parse_args()
    import_products(dry_run=args.dry_run)


if __name__ == "__main__":
    main()
