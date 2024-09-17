package cvs

import "golang.org/x/crypto/pbkdf2"
import "crypto/sha256"

func DeriveKey(password string, salt []byte) []byte {
	return pbkdf2.Key([]byte(password), salt, 250000, 32, sha256.New)
}
