# ca证书私钥
CA_KEY_FILE=ca.key
# ca证书
CA_CRT_FILE=ca.crt
# ca过期时间
CA_EXPIRE=36500
# ca证书机构
CA_CN=JoeKerouac
# 生成的客户端证书私钥
CLIENT_KEY_FILE=client.key
# 生成的客户端证书文件
CLIENT_CRT_FILE=client.crt
# 客户端证书过期时间
CLIENT_EXPIRE=36500
# 客户端证书机构
CLIENT_CN=my@example.com
# 客户端证书STATE
STATE=河南
# 客户端证书企业名
ENTERPRISE_NAME=JoeKerouac
# 客户端证书申请部门
ORGANIZATIONAL_UNIT=dev




# 生成CA证书
createCA() {
echo "开始生成CA证书"
openssl genrsa -out ${CA_KEY_FILE} 4096 >/dev/null 2>&1

openssl req -x509 -new -nodes -sha512 -days ${CA_EXPIRE} \
  -subj "/C=CN/ST=Henan/L=Henan/O=Joe/OU=IT/CN=${CA_CN}" \
  -key ${CA_KEY_FILE} \
  -out ${CA_CRT_FILE} >/dev/null 2>&1
echo "CA证书生成完毕"
}


# 创建客户端证书
createCert() {
echo "开始生成证书"
cat << EOF > common.csr.conf
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = CN
ST = ${STATE}
L = ${STATE}
O = ${ENTERPRISE_NAME}
OU = ${ORGANIZATIONAL_UNIT}
CN = ${CLIENT_CN}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster
DNS.5 = kubernetes.default.svc.cluster.local

[ v3_ext ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=@alt_names
EOF


# 生成一个2048bit的server.key
openssl genrsa -out ${CLIENT_KEY_FILE} 2048 >/dev/null 2>&1
# 使用上边的CSR请求文件生成服务器证书CSR（证书请求）
openssl req -new -key ${CLIENT_KEY_FILE} -out tls.csr -config common.csr.conf >/dev/null 2>&1
# 生成服务器证书
openssl x509 -req -in tls.csr -CA ${CA_CRT_FILE} -CAkey ${CA_KEY_FILE} -CAcreateserial -out ${CLIENT_CRT_FILE} -days ${CLIENT_EXPIRE} -extensions v3_ext -extfile common.csr.conf >/dev/null 2>&1
rm -rf common.csr.conf tls.csr ca.srl
echo "证书生成完毕"
}

createCA
createCert
