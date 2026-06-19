from backend.app.services.contract_examples import response_example


class CheckoutService:
    def create_payment_intent(self, request: dict) -> dict:
        return response_example("/create-payment-intent", "post")

    def confirm_order(self, request: dict) -> dict:
        return response_example("/orders/confirm", "post")

    def get_orders(self, uid: str) -> dict:
        return response_example("/orders/{uid}", "get")
