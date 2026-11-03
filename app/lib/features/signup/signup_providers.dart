import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:apply_track/features/signup/signup_gateway.dart';

final Provider<SignupGateway> signupGatewayProvider = Provider<SignupGateway>(
  (Ref ref) => const FakeServerSignupGateway(),
);
