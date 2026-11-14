# Himel Zone Android starter (Flutter)

এটি Himel Zone-এর একটি Flutter Android starter project। এতে কালো-গোল্ড UI, Firebase email/password login ও registration flow, profile, quiz এবং points UI আছে।

## গুরুত্বপূর্ণ সীমাবদ্ধতা
- Firebase কনফিগার না থাকলে অ্যাপ preview mode-এ চলে।
- Firebase চালু করতে `flutterfire configure` চালিয়ে `lib/firebase_options.dart` তৈরি করুন এবং `main.dart`-এ `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` ব্যবহার করুন।
- Firestore security rules-এ points পরিবর্তন সাধারণ ব্যবহারকারীর জন্য বন্ধ রাখা হয়েছে। বাস্তব পয়েন্ট যোগ করতে trusted Cloud Function/সার্ভার endpoint তৈরি করতে হবে; ক্লায়েন্ট থেকে points update করবেন না।
- Admin screen এখন placeholder। বাস্তব admin role custom claims দিয়ে trusted server থেকে দিতে হবে; client-side role field বিশ্বাস করবেন না।
- পয়েন্টগুলো ডেমো/গেম স্কোর; নগদ অর্থ নয়। অ্যাপে টাকা জমা, বাজি, জুয়া বা নগদ উত্তোলন নেই।

## চালানোর ধাপ
1. Flutter SDK এবং Android Studio ইনস্টল করুন।
2. টার্মিনালে এই ফোল্ডারে যান।
3. `flutter create .`
4. `flutter pub get`
5. Firebase project তৈরি করে Android app যোগ করুন।
6. `dart pub global activate flutterfire_cli`
7. `flutterfire configure`
8. Firebase Console-এ Authentication > Email/Password চালু করুন।
9. Firestore Database তৈরি করে `firestore.rules` deploy করুন।
10. `flutter run` দিয়ে পরীক্ষা করুন।
11. APK বানাতে: `flutter build apk --release`

## নিরাপত্তা
এই starter production-ready নয়। প্রকাশের আগে server-side point awarding, admin custom claims, abuse/rate-limit checks, privacy policy, terms, data deletion এবং security testing যোগ করুন।


## Android launcher name
`flutter create .` করার পর `android/app/src/main/AndroidManifest.xml`-এ
`<application android:label="Himel Zone" ...>` নিশ্চিত করুন।
প্রয়োজনে `android/app/src/main/res/values/strings.xml`-এ app_name-ও `Himel Zone` দিন।
