package cvs

import "testing"

func TestEncryptDecrypt(t *testing.T) {

	t.Run("self-check", func(t *testing.T) {

		buffer := []byte("Hello, World!")
		password := "password123"

		encrypted := Encrypt(buffer, password)
		decrypted := Decrypt(encrypted, password)

		if string(buffer) != string(decrypted) {
			t.Errorf("Expected '%s' but got '%s'", buffer, decrypted)
		}

	})

}

