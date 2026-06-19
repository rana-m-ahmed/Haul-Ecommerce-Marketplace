const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
} = require("firebase/firestore");
const fs = require("fs");

function cartItem(quantity) {
  return {
    productId: "p017",
    quantity,
    priceSnapshot: 64.0,
    addedAt: "2026-06-17T12:00:00Z",
    updatedAt: "2026-06-17T12:00:00Z",
  };
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: "hual-rules-test",
    firestore: {
      rules: fs.readFileSync("firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });

  try {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users/alice/cart/item_1"), cartItem(1));
    });

    const aliceDb = testEnv.authenticatedContext("alice").firestore();
    const bobDb = testEnv.authenticatedContext("bob").firestore();

    await assertSucceeds(getDoc(doc(aliceDb, "users/alice/cart/item_1")));
    await assertFails(getDoc(doc(bobDb, "users/alice/cart/item_1")));
    await assertSucceeds(setDoc(doc(aliceDb, "users/alice/cart/item_20"), cartItem(20)));
    await assertFails(setDoc(doc(aliceDb, "users/alice/cart/item_0"), cartItem(0)));
    await assertFails(setDoc(doc(aliceDb, "users/alice/cart/item_21"), cartItem(21)));
    await assertFails(setDoc(doc(bobDb, "users/alice/cart/item_bob"), cartItem(1)));
    await assertSucceeds(setDoc(doc(aliceDb, "users/alice/wishlist/p017"), {
      productId: "p017",
      addedAt: "2026-06-17T12:00:00Z",
    }));
    await assertFails(getDoc(doc(bobDb, "users/alice/wishlist/p017")));
    await assertFails(setDoc(doc(aliceDb, "users/alice/orders/order_1"), {
      orderNumber: "HUL-20260617-0001",
      items: [],
      total: 64.0,
      currency: "usd",
      status: "confirmed",
      shippingAddress: {},
      paymentIntentId: "pi_test_123",
      createdAt: "2026-06-17T12:10:00Z",
    }));
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
