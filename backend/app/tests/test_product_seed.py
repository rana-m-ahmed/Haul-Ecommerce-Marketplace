from backend.app.services.catalog_repository import LocalSeedCatalogRepository


def test_seed_search_tokens_cover_real_product_attributes() -> None:
    products = LocalSeedCatalogRepository().list_products()
    lamp = next(product for product in products if product["id"] == "p017")

    assert len(products) == 50
    assert {"ceramic", "warm", "clay", "lighting", "home"}.issubset(
        set(lamp["searchTokens"])
    )


def test_seed_preserves_required_catalog_states() -> None:
    products = LocalSeedCatalogRepository().list_products()

    assert any(product["isSale"] for product in products)
    assert any(product["isNew"] for product in products)
    assert any(product["inventory"] == 0 for product in products)
    assert any(not product["imageUrls"] for product in products)
