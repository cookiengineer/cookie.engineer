package cvs

import "cookie.engineer/console"
import "crypto/aes"
import "crypto/cipher"
import "encoding/hex"
import "strconv"

func Decrypt(buffer []byte, password string) []byte {

	var result []byte

	console.Group("cvs/Decrypt")

	salt := buffer[0:16]
	iv := buffer[16:16+12]
	data := buffer[16+12:]
	key := DeriveKey(password, salt)

	console.Log("Salt:          " + hex.EncodeToString(salt))
	console.Log("IV:            " + hex.EncodeToString(iv))
	console.Log("Key:           " + hex.EncodeToString(key))
	console.Log("Input Buffer:  " + strconv.Itoa(len(data)) + " bytes")

	block, err0 := aes.NewCipher(key)

	if err0 == nil {

		aes_gcm, err1 := cipher.NewGCM(block)

		if err1 == nil {

			tmp, err2 := aes_gcm.Open(nil, iv, data, nil)

			if err2 == nil {
				console.Log("Output Buffer: " + strconv.Itoa(len(tmp)) + " bytes")
				result = tmp
			}

		}

	}

	console.GroupEnd("cvs/Decrypt")

	return result

}

