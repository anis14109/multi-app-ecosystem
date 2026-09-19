// Ignore for testing purposes

import 'package:flutter_app/app/app.dart';
import 'package:flutter_app/auth/bloc/auth_bloc.dart';
import 'package:flutter_app/auth/bloc/auth_state.dart';
import 'package:flutter_app/auth/view/auth_view.dart';
import 'package:flutter_app/core/models/user_model.dart';
import 'package:flutter_app/core/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends Mock implements AuthBloc {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  const user = UserModel(
    id: 1,
    name: 'Test User',
    email: 'test@example.com',
  );

  group('App', () {
    testWidgets('renders LoginPage when unauthenticated', (tester) async {
      final bloc = MockAuthBloc();
      when(() => bloc.state).thenReturn(const AuthUnauthenticated());
      when(
        () => bloc.stream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());

      await tester.pumpWidget(
        App(authBloc: bloc, authRepository: MockAuthRepository()),
      );

      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('renders HomePage when authenticated', (tester) async {
      final bloc = MockAuthBloc();
      when(() => bloc.state).thenReturn(const AuthenticatedOnline(user: user));
      when(
        () => bloc.stream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());

      await tester.pumpWidget(
        App(authBloc: bloc, authRepository: MockAuthRepository()),
      );

      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('renders LockScreen when locally locked', (tester) async {
      final bloc = MockAuthBloc();
      when(() => bloc.state).thenReturn(const AuthLocalLocked(hasPin: true));
      when(
        () => bloc.stream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());

      await tester.pumpWidget(
        App(authBloc: bloc, authRepository: MockAuthRepository()),
      );

      expect(find.byType(LockScreen), findsOneWidget);
    });
  });
}
