class DemoPaymentResponse {
  final bool isSuccess;
  final String message;
  final String? paymentId;

  const DemoPaymentResponse({
    required this.isSuccess,
    required this.message,
    this.paymentId,
  });
}

class PaymentService {
  static const String successUpiId = 'success@razorpay';
  static const String failureUpiId = 'failure@razorpay';
  static const String demoPin = '1234';

  const PaymentService();

  DemoPaymentResponse processDemoUpiPayment({
    required String upiId,
    required String upiPin,
    required double amount,
  }) {
    if (amount <= 0) {
      return const DemoPaymentResponse(
        isSuccess: false,
        message: 'Amount must be greater than 0.',
      );
    }

    final normalizedUpiId = upiId.trim().toLowerCase();
    final normalizedPin = upiPin.trim();

    if (normalizedPin != demoPin) {
      return const DemoPaymentResponse(
        isSuccess: false,
        message: 'Invalid UPI PIN. Please try again.',
      );
    }

    if (normalizedUpiId == successUpiId) {
      final paymentId = 'demo_pay_${DateTime.now().millisecondsSinceEpoch}';
      return DemoPaymentResponse(
        isSuccess: true,
        message: 'Payment successful.',
        paymentId: paymentId,
      );
    }

    if (normalizedUpiId == failureUpiId) {
      return const DemoPaymentResponse(
        isSuccess: false,
        message: 'Payment declined by the bank.',
      );
    }

    return const DemoPaymentResponse(
      isSuccess: false,
      message: 'UPI ID could not be verified. Please check and try again.',
    );
  }
}
