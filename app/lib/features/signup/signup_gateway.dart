final class SignupData {
  const SignupData({required this.name, required this.email});

  final String name;
  final String email;
}

sealed class SignupResult {
  const SignupResult();
}

final class SignupAccepted extends SignupResult {
  const SignupAccepted();
}

final class SignupRejected extends SignupResult {
  const SignupRejected(this.message);

  final String message;
}

abstract interface class SignupGateway {
  Future<SignupResult> submit(SignupData data);
}

/// Pretends to be the server until Phase 3.
final class FakeServerSignupGateway implements SignupGateway {
  const FakeServerSignupGateway();

  @override
  Future<SignupResult> submit(SignupData data) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (data.email.toLowerCase() == 'taken@example.com') {
      return const SignupRejected('This email is already used');
    }
    return const SignupAccepted();
  }
}
