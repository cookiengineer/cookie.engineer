package cvs

import "cookie.engineer/console"
import "crypto/aes"
import "crypto/cipher"
import "crypto/rand"
import "encoding/hex"
import "strconv"

func Encrypt(buffer []byte, password string) []byte {

	var result []byte

	console.Group("cvs/Encrypt")

	salt := make([]byte, 16)
	rand.Read(salt)

	iv := make([]byte, 12)
	rand.Read(iv)

	key := DeriveKey(password, salt)

	console.Log("Salt:          " + hex.EncodeToString(salt))
	console.Log("IV:            " + hex.EncodeToString(iv))
	console.Log("Key:           " + hex.EncodeToString(key))
	console.Log("Input Buffer:  " + strconv.Itoa(len(buffer)) + " bytes")

	block, err0 := aes.NewCipher(key)

	if err0 == nil {

		aes_gcm, err1 := cipher.NewGCM(block)

		if err1 == nil {

			tmp := aes_gcm.Seal(nil, iv, buffer, nil)

			console.Log("Output Buffer: " + strconv.Itoa(len(tmp)) + " bytes")

			result = append(result, salt...)
			result = append(result, iv...)
			result = append(result, tmp...)

		}

	}

	console.GroupEnd("cvs/Encrypt")

	return result

}
