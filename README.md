# miniPKI
miniPKI is a set of scripts to build a simple PKI structure using OpenSSL.

Purposes:
* generate server, client or peer X.509 certificates using ECDSA with prime256v1
  * for mutual TLS verification/authentication
  * with Subject Alternative Name (SAN) 
* Control certificate expiration
* Revoke a certificate

From a terminology perspective: an Intermediate Certificate Authority (CA) is called a Signing Authority (SA) in this document. 

## Quick Start

* Clone the miniPKI: `git clone ` and change the directory: `cd miniPKI`
* Create a Certificate Authority (CA): `sudo bin/ca.sh '/CN=ca.example.com'`
* Create a Signing Authority (SA): `sudo bin/sa.sh '/CN=sa.example.com'`
* Create the chain of certificates CA+SA: `sudo cat certs/ca.crt certs/sa.crt >certs/ca-chain.pem`
* `for(;;)` Create a private key and a X.509 certificate signed by the SA: `sudo bin/cert.sh -a 'DNS:server1.example.com,IP:10.0.0.100' server1`
* Create key and certificate for a client: `sudo bin/cert.sh -u client1`
* Check soon-to-expiry certificates: `sudo bin/check.sh`
* Revoke a certificate: `sudo bin/revoke.sh server1.crt`


## Detailed Instructions
Things to consider before generating keys and certificates:
* Dependency: these scripts use [OpenSSL](https://www.openssl.org/). Please install it first.
* Cryptography: by default these scripts use **ECDSA** with [prime256v1]9https://tools.ietf.org/html/rfc44920. To use well-known **RSA** add option `-r` to all scripts
* Location of your PKI. Good place will be `/var/CA`
* Ownership of your PKI. By default **root** owns everything. That is why you need to run scripts as `sudo`. However, it could be owned by an automation ID. Then, run scripts under this ID without `sudo`
* Domain Name for your certificates. The DNS name should be included into a Subject Alternative Name (SAN) as per [requirements](https://support.apple.com/en-us/HT210176). But consider to use it for hostnames as well (i.e. server1.example.com). So, your key/certificate will be saved as server1.example.com.key / server1.example.com.crt
* Your distinguished name (DN) could be used for additional access control. By default it is empty. Update the parameter SUBJ_PREFIX in the file etc/params.sh (i.e. "/C=US/ST=CA/L=Fremont/O=Example Inc").
* Validity period for server/client certificates. One or two years will be a good choice. Indeed, [Apple requires](https://support.apple.com/en-us/HT210176) not more than 825 days. Update the parameter KDAYS in the file etc/params.sh.

### Step 1: Create the root CA
Consider the following:
* root CA's common name (CN). Could be *rootCA.example.com*. *ca* is used by default
* validity period. 20 years by default
  
Run 
```bash
bin/ca.sh [switch] [subject or hostname]
  where optional subject in format:
    "/C=US/ST=CA/L=Fremont/O=Example Inc./CN=root.example.com"
	dafault "/CN=ca"
	
    optional switches:
      -r  use RSA, by default: ECDSA with prime256v1
      -v  be verbose
```

If you used the non-default root name, update the following parameters in the file **etc/params.sh**:
```
CA_KEY=$DIR_KEY/ca.key	#-- root CA private key
CA_CRT=$DIR_CRT/ca.crt  #-- root CA public certificate
```

You will use these parameters to sign SAs

### Step 2: Create Intermediate CAs / Signing Authorities (SAs)
Consider the following:
* number of SAs. It is not a bad idea to have two SAs: one for signing and one for backup. 
* SA's common name (CN). Could be *sa1.example.com*. *sa* is used by default
* validity period. 10 years by default

Run 
```
bin/sa.sh [switch] [subject or hostname]

          where optional subject in format:
          "/C=US/ST=CA/L=Fremont/O=Example/CN=sa1.example.com"
            default: "${SUBJ_PREFIX}${SA_SUBJ}"
         or hostname (i.e sa1.example.com)

          optional switches:
            -c  ca_cert.crt	CA's certificate
            -k  ca.key		CA's key
            -r                  use RSA, by default: ECDSA with prime256v1	    
            -v  		be verbose
```
If you used the non-default SA name(s), update the following parameters in the file **etc/params.sh** with the primary SA's name:
```
SA_KEY=$DIR_KEY/sa.key      #-- Signing Authority private key
SA_CRT=$DIR_CRT/sa.crt      #-- Signing Authority public certificate
```

You will use these parameters to sign all others certificates

### Step 3: Create CA chain 
Now store the CA privae key **keys/ca.key** in a save place. From now it only could be used for the following:
* revoke a compromized SA certificate
* create a new SA certificate after expiration
* create a new CA certificate after expiration

Create the file **ca-chain.pem**: `cat certs/ca.crt certs/sa.crt >./certs/ca-chain.pem`

### Step S+1: Creat a private key and a certificate for a server or client

Run 
```
bin/cert.sh [switch] subject_or_hostname
       where subject in format:
       "/C=US/ST=CA/L=Fremont/O=Example/CN=www.example.com"
        default: "${SUBJ_PREFIX}${SUBJ}"
       or hostname (i.e www)

       optional switches:
         -a 'subjectAltName' - i.e. 'DNS:example.com,DNS:www.example.com,IP:10.0.0.100'
         -b              copy the key and the cert to a local directory
         -c  sa_cert.crt SA's certificate
         -k  sa.key      SA's key
         -u              create a CLIENT certificate
	 -p              create a PEER certificate (SERVER+CLIENT) [by default]
	 -s              create a SERVER certificate
	 -r              use RSA, by default: ECDSA with prime256v1
         -v              be verbose
         -h              this help
```

## Description

The miniPKI directory and file structure:
* `./bin` - directory with executable scripts
  * `./bin/ca.sh` - generate a private key and a self-signed certificate for a Certificate Authority (CA). Run it only once.
  * `./bin/cert.sh` - generate a private key and a certificate signed by the SA
  * `./bin/check.sh` - find soon-to-expire (60 days by default) certificates
  * `./bin/revoke.sh` - revoke a certificate and update the certificate revocation list (CRL)
  * `./bin/sa.sh` - generate a private key and sign the certificate by CA for a Signing Authority (SA). Run it few times.
* `./certs` - directory for certificates
* `./certs.backup` - backup directory for certificates in format serial_index.pem
* `./crl` - directory for certificate revocation lists (CRL)
* `./csr` - directory for certificate signing requests (CSR)
* `./etc` - directory for configuration files
  * `./etc/params.sh` - file with common variables for scripts
  * `./etc/minipki.cnf` - configuration file for OpenSSL
* `./keys` - directory for private keys. It should have the highest protection
* `./lib` - directory for other files
  * `./lib/cert-*.cnf` - parts of the dynamic configuration
  * `./lib/crlnumber*` - index for CRLs
  * `./lib/function.sh` - file with common functions for scripts
  * `./lib/index.txt*` - list (database) of certificates
  * `./lib/serial*` - index for certificates
* `./log` - directory for logs. Purge these logs if too big

See Also:
* [OpenSSL Certificate Authority](https://jamielinux.com/docs/openssl-certificate-authority/index.html)

### Subject Alternative Name (SAN) 
[SAN - wiki](https://en.wikipedia.org/wiki/Subject_Alternative_Name)
TLS server certificates must present the DNS name of the server in the Subject Alternative Name extension of the certificate. DNS names in the CommonName of a certificate are no longer trusted.[Apple support](https://support.apple.com/en-us/HT210176)
Source: https://gist.github.com/fntlnz/cf14feb5a46b2eda428e000157447309
It has become important (and modern Firefox and Chrome at least demand it) that certificates be generated specifying DNS entries representing the domain name using the subjectAltName config setting. Source: https://stackoverflow.com/a/49087278.

Examples from [man](https://www.openssl.org/docs/manmaster/man5/x509v3_config.html#Subject-Alternative-Name):
* email:copy,email:my@other.address,URI:http://my.url.here/
* IP:192.168.7.1
* IP:13::17
* email:my@other.address,RID:1.2.3.4
* otherName:1.2.3.4;UTF8:some other identifier

## Tips and Tricks

### No sudo
To run scripts you do not really need the elevated root privileges. The only one reason why `sudo` is used that all miniPKI structure is owned by **root**. And permission to the private SA key is that only the owner can read. Thus, change owhership on miniPKI's directories and files and you can run scripts whith that ID only. But now you need to protect the SA's private key.

### Run from any directory
For automation of X.509 certificates enrolment, it is beneficial to run these scripts from any directory. To achieve this, specify the absolute path to `dir = absolute_path here` in the file **./etc/minipki.cnf**, line 7. 

## To Do
* Implement OCSP
