import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
  // MUHIM: AES-256 uchun 32 ta harfdan iborat maxfiy kalit.
  // Buni hech qachon o'zgartirmang, aks holda eski kalitlar o'qilmay qoladi.
  static final _key = enc.Key.fromUtf8('AristokratMebelSecretKey2026!!!!');
  static final _iv = enc.IV.fromLength(16);
  static final _encrypter = enc.Encrypter(enc.AES(_key));

  // Matnni shifrlash (Supabase'ga shu ketadi)
  static String encryptText(String plainText) {
    if (plainText.isEmpty) return '';
    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      return '';
    }
  }

  // Shifrlangan matnni asl holiga qaytarish
  static String decryptText(String encryptedText) {
    if (encryptedText.isEmpty) return '';
    try {
      final decrypted = _encrypter.decrypt64(encryptedText, iv: _iv);
      return decrypted;
    } catch (e) {
      return ''; // Xato bo'lsa yoki kalit o'zgargan bo'lsa bo'sh qaytadi
    }
  }
}
