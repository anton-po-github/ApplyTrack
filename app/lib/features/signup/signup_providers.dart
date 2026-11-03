import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phase2_widgets/features/signup/signup_gateway.dart';

final Provider<SignupGateway> signupGatewayProvider = Provider<SignupGateway>(
  (Ref ref) => const FakeServerSignupGateway(),
);
