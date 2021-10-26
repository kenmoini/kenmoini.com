---
title: "Building x509 PKI in Golang - File Encryption - 7 / 100 DoC"
date: 2021-03-15T07:42:47-05:00
draft: false
toc: false
hero: /images/posts/heroes/go-pki-file-encryption.png
tags:
  - ssl
  - pki
  - x509
  - golang
  - programming
  - rsa
  - security
  - certificates
  - keys
  - encryption
authors:
  - Ken Moini
---

> ***Part 3 of a small series into building a Public Key Infrastructure chain with Golang***

Files and directories - check.  Before we get to generating keys and certificates we need to go over some simple file encryption in Golang to protect our Private Keys, and maybe even certificates.  Whatever text-based file (like a PEM file) could be encrypted by the following methods.

## Series Table of Contents

- [Background](https://kenmoini.com/blog/building-x509-in-golang-background/)
- [Directory Structure](https://kenmoini.com/blog/building-x509-in-golang-directory-structure/)
- [File Encryption](https://kenmoini.com/blog/building-x509-in-golang-file-encryption/)
- [Key Pairs](https://kenmoini.com/blog/building-x509-in-golang-key-pairs/)

## Why Encrypt Keys Externally?

Each Key Pair is composed of a Private and a Public Key.  The Public Key is of course, public data in nature, it's meant to be shared.   You can share your public key, people can encrypt data with it, send that encrypted data to you, where only your Private Key could decrypt it.

Now, the Private Key is very important - you keep this safe, and ideally you protect it with a passphrase that would encrypt the contents so even if the private key file is compromised, the key couldn't be used without the passphrase to decrypt it.

Current methods of encrypting the Private Key are based in [RFC1423](https://tools.ietf.org/html/rfc1423) - which evidently, [are not so secure](https://golang.org/pkg/crypto/x509/#EncryptPEMBlock)...

> Legacy PEM encryption as specified in RFC 1423 is insecure by design. Since it does not authenticate the ciphertext, it is vulnerable to padding oracle attacks that can let an attacker recover the plaintext.

***YIKES!***

Ok, no problem, there are other secure methods of encrypting data.

*The final scripts and extra goodies will be provided at the end...whenever I finish writing all this...*

## Encrypting Files

So first thing is how we're going to do this:

1. Take in a passphrase and a byte slice containing a blob of text like a PEM
2. Create an AES Cipher from the passphrase
3. Make an AES-GCM data block container to encrypt the data

Sounds pretty easy eh?  Well, there are a few minor steps in some of those larger steps...

### func.encryption.go

```go

// passphraseToHash returns a hexadecimal string of an SHA1 checksumed passphrase
func passphraseToHash(pass string) (string, []byte) {
	// The salt is used as a unique string to defeat rainbow table attacks
	saltHash := md5.New()
	saltHash.Write([]byte(pass))
	saltyBytes := saltHash.Sum(nil)
	salt := hex.EncodeToString(saltyBytes)

	saltyPass := []byte(pass + salt)
	hasher := sha1.New()
	hasher.Write(saltyPass)

	hash := hasher.Sum(nil)

	return hex.EncodeToString(hash), hash
}

// encryptBytes is a function that takes a plain byte slice and a passphrase and returns an encrypted byte slice
func encryptBytes(bytesIn []byte, passphrase string) []byte {
	passHash, _ := passphraseToHash(passphrase)
	targetPassHash := passHash[0:32]

	// Create an AES Cipher
	block, err := aes.NewCipher([]byte(targetPassHash))
	check(err)

	// Create a new gcm block container
	gcm, err := cipher.NewGCM(block)
	check(err)

	// Never use more than 2^32 random nonces with a given key because of the risk of repeat.
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		log.Fatal(err)
	}

	// Seal will encrypt the file using the GCM mode, appending the nonce and tag (MAC value) to the final data, so we can use it to decrypt it later.
	return gcm.Seal(nonce, nonce, bytesIn, nil)
}
```

Now, something to note about the encryption function is that it returns a byte slice - to store this in a file or transmit to some external source you'd want to encode the encrypted bytes with Base64.

## Decrypting Files

Decrypting the files is basically the same process but just in reverse...if coming in from a Base64 encoded source, ensure to decode it to the byte slice first.

```go
// decryptBytes takes in a byte slice from a file and a passphrase then returns if the encrypted byte slice was decrypted, if so the plaintext contents, and any errors
func decryptBytes(bytesIn []byte, passphrase string) (decrypted bool, plaintextBytes []byte, err error) {
	// bytesIn must be decoded from base 64 first
	// b64.StdEncoding.DecodeString(bytesIn)

	passHash, _ := passphraseToHash(passphrase)
	targetPassHash := passHash[0:32]

	// Create an AES Cipher
	block, err := aes.NewCipher([]byte(targetPassHash))
	if err != nil {
		log.Panic(err)
		return false, []byte{}, err
	}

	// Create a new gcm block container
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		log.Panic(err)
		return false, []byte{}, err
	}

	nonce := bytesIn[:gcm.NonceSize()]
	ciphertext := bytesIn[gcm.NonceSize():]
	plaintextBytes, err = gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		log.Panic(err)
		return false, []byte{}, err
	}

	// successfully decrypted
	return true, plaintextBytes, nil
}
```

## Helper Functions

Some helper functions that'll make the rest of the above code work...and then some extras to help plumb things quickly.

### func.file.go

```go
// ReadFileToBytes will return the contents of a file as a byte slice
func ReadFileToBytes(path string) ([]byte, error) {
	absolutePath, err := filepath.Abs(path)
	if err != nil {
		return nil, err
	}
	return ioutil.ReadFile(absolutePath)
}

// WriteByteFile creates a file from a byte slice with an optional filemode, only if it's new, and populates it - can force overwrite optionally
func WriteByteFile(path string, content []byte, mode int, overwrite bool) (bool, error) {
	var fileMode os.FileMode
	if mode == 0 {
		fileMode = os.FileMode(0600)
	} else {
		fileMode = os.FileMode(mode)
	}
	fileCheck, err := FileExists(path)
	check(err)
	// If not, create one with a starting digit
	if !fileCheck {
		err = ioutil.WriteFile(path, content, fileMode)
		check(err)
		return true, err
	}
	// If the file exists and we want to overwrite it
	if fileCheck && overwrite {
		err = ioutil.WriteFile(path, content, fileMode)
		check(err)
		return true, err
	}
	return false, nil
}

// B64EncodeBytesToStr converts a byte slice to a Base64 Encoded String
func B64EncodeBytesToStr(input []byte) string {
	return b64.StdEncoding.EncodeToString(input)
}

// B64DecodeBytesToStr converts a Base64 byte slice to a Base64 Decoded Byte slice
func B64DecodeBytesToBytes(input []byte) ([]byte, error) {
	return B64DecodeStrToBytes(string(input))
}

// B64DecodeStrToBytes converts a Base64 string to a Base64 Decoded Byte slice
func B64DecodeStrToBytes(input string) ([]byte, error) {
	return b64.StdEncoding.DecodeString(input)
}
```

### func.logging.go

```go
// check does error checking
func check(e error) {
	if e != nil {
		log.Printf("error: %v", e)
	}
}
```

## Next Steps

With that you could now rest assured that your PEM files (or whatever really) can be secured - note that again, this is not the RFC1432 standard PEM encryption so to use in other applications you'd want to leverage these Golang in a simple Vaulting application that can quickly encrypt/decrypt files for use with other systems.

Now that we've got a decent encryption mechanism, let's go make some [Key Pairs](https://kenmoini.com/blog/building-x509-in-golang-key-pairs/)...