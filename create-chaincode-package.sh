#!/bin/bash
# package-chaincode.sh

# Clean start
rm -rf chaincode-build
mkdir -p chaincode-build
cd chaincode-build

# Create the chaincode
cat > kvstore.go << 'EOF'
package main

import (
    "fmt"
    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type KVStore struct {
    contractapi.Contract
}

func (s *KVStore) Set(ctx contractapi.TransactionContextInterface, key string, value string) error {
    return ctx.GetStub().PutState(key, []byte(value))
}

func (s *KVStore) Get(ctx contractapi.TransactionContextInterface, key string) (string, error) {
    value, err := ctx.GetStub().GetState(key)
    if err != nil {
        return "", fmt.Errorf("failed to read: %v", err)
    }
    if value == nil {
        return "", fmt.Errorf("key not found: %s", key)
    }
    return string(value), nil
}

func main() {
    chaincode, err := contractapi.NewChaincode(&KVStore{})
    if err != nil {
        fmt.Printf("Error creating chaincode: %s", err)
        return
    }
    if err := chaincode.Start(); err != nil {
        fmt.Printf("Error starting chaincode: %s", err)
    }
}
EOF

# Initialize Go module
go mod init kvstore
go mod tidy
GOOS=linux GOARCH=arm GOARM=7 go build -o kvstore

# Create the correct directory structure
mkdir -p src
mv kvstore src/
mv go.* src/

# Create connection.json in src directory
cat > src/connection.json << 'EOF'
{
    "address": "localhost:9999",
    "dial_timeout": "10s",
    "tls_required": false
}
EOF

# Create metadata.json
cat > metadata.json << 'EOF'
{
    "type": "ccaas",
    "label": "kvstore_1.0"
}
EOF

# Create the package
COPYFILE_DISABLE=1 tar --exclude='._*' --exclude='.DS_Store' -czf code.tar.gz -C src .
COPYFILE_DISABLE=1 tar --exclude='._*' --exclude='.DS_Store' -czf kvstore.tar.gz metadata.json code.tar.gz

# Move to chaincode-packages
cd ..
mkdir -p chaincode-packages
mv chaincode-build/kvstore.tar.gz chaincode-packages/

# Cleanup
rm -rf chaincode-build
