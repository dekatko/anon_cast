import 'package:firebase_auth/firebase_auth.dart'; // Assuming Firebase Authentication

class AuthenticationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign up a new user (if applicable for your app)
  Future<UserCredential?> signUp(String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        print('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        print('The account already exists for that email.');
      }
      return null; // Handle other exceptions as needed
    } catch (e) {
      print(e.toString()); // Log any other errors
      return null;
    }
  }

  // Login an administrator using email and password
  Future<User?> loginAdmin(String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        print('Wrong password provided for that user.');
      }
      return null; // Handle other exceptions as needed
    }
  }

  // Sign in a student anonymously
  Future<User?> signInAnonymously() async {
    try {
      final UserCredential userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed') {
        print('Anonymous auth is disabled.');
      } else {
        print(e.toString()); // Log other errors
      }
      return null;
    }
  }

  // Sign out the current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Check if a user is currently signed in
  Stream<User?> get authStateChanges => _auth.authStateChanges();

// Additional methods can be added here, like password reset
}
