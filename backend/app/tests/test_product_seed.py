from backend.app.services.catalog_repository import LocalSeedCatalogRepository


def test_seed_manifest_preserves_required_catalog_shape() -> None:
    products = LocalSeedCatalogRepository().list_products()
    category_counts: dict[str, int] = {}
    for product in products:
        category_counts[product["category"]] = category_counts.get(product["category"], 0) + 1

    assert len(products) == 50
    assert [product["id"] for product in products] == [f"p{index:03d}" for index in range(1, 51)]
    assert category_counts == {
        "fashion": 9,
        "electronics": 7,
        "home": 9,
        "skincare": 8,
        "fitness": 8,
        "accessories": 9,
    }


def test_seed_products_have_searchable_catalog_fields() -> None:
    products = LocalSeedCatalogRepository().list_products()

    assert all(product["searchTokens"] for product in products)
    assert all(product["name"] for product in products)
    assert all(product["category"] for product in products)
    assert any(product["isSale"] for product in products)
    assert any(product["isNew"] for product in products)
    assert any(product["inventory"] == 0 for product in products)
