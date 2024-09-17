package cvs

import "encoding/hex"
import "crypto/sha256"

func DeriveFilename(password string) string {

	hasher := sha256.New()
	hasher.Write([]byte(password))
	bytes := hasher.Sum(nil)

	return hex.EncodeToString(bytes) + ".cv"

}
