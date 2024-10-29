package types

import (
	"encoding/json"
	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/sei-protocol/sei-cryptography/pkg/encryption/elgamal"
	"github.com/sei-protocol/sei-cryptography/pkg/zkproofs"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestMsgTransfer_FromProto(t *testing.T) {
	testDenom := "factory/sei1ft98au55a24vnu9tvd92cz09pzcfqkm5vlx99w/TEST"
	sourcePrivateKey, _ := elgamal.GenerateKey()
	destPrivateKey, _ := elgamal.GenerateKey()
	eg := elgamal.NewTwistedElgamal()
	sourceKeypair, _ := eg.KeyGen(*sourcePrivateKey, testDenom)
	destinationKeypair, _ := eg.KeyGen(*destPrivateKey, testDenom)

	amountLo := uint64(100)
	amountHi := uint64(0)

	remainingBalance := uint64(200)

	// Encrypt the amount using source and destination public keys
	sourceCiphertextAmountLo, sourceCiphertextAmountLoR, _ := eg.Encrypt(sourceKeypair.PublicKey, amountLo)
	sourceCiphertextAmountLoValidityProof, _ :=
		zkproofs.NewCiphertextValidityProof(&sourceCiphertextAmountLoR, sourceKeypair.PublicKey, sourceCiphertextAmountLo, amountLo)
	sourceCiphertextAmountHi, sourceCiphertextAmountHiR, _ := eg.Encrypt(sourceKeypair.PublicKey, amountHi)
	sourceCiphertextAmountHiValidityProof, _ :=
		zkproofs.NewCiphertextValidityProof(&sourceCiphertextAmountHiR, sourceKeypair.PublicKey, sourceCiphertextAmountHi, amountHi)

	ciphertext := &Ciphertext{}
	fromAmountLo := ciphertext.ToProto(sourceCiphertextAmountLo)
	fromAmountHi := ciphertext.ToProto(sourceCiphertextAmountHi)

	destinationCipherAmountLo, destinationCipherAmountLoR, _ := eg.Encrypt(destinationKeypair.PublicKey, amountLo)
	destinationCipherAmountLoValidityProof, err :=
		zkproofs.NewCiphertextValidityProof(&destinationCipherAmountLoR, destinationKeypair.PublicKey, destinationCipherAmountLo, amountLo)
	destinationCipherAmountHi, destinationCipherAmountHiR, _ := eg.Encrypt(destinationKeypair.PublicKey, amountHi)
	destinationCipherAmountHiValidityProof, err :=
		zkproofs.NewCiphertextValidityProof(&destinationCipherAmountHiR, destinationKeypair.PublicKey, destinationCipherAmountHi, amountHi)

	destinationAmountLo := ciphertext.ToProto(destinationCipherAmountLo)
	destinationAmountHi := ciphertext.ToProto(destinationCipherAmountHi)

	remainingBalanceCiphertext, remainingBalanceRandomness, _ := eg.Encrypt(sourceKeypair.PublicKey, remainingBalance)
	remainingBalanceProto := ciphertext.ToProto(remainingBalanceCiphertext)

	remainingBalanceCommitmentValidityProof, err :=
		zkproofs.NewCiphertextValidityProof(&remainingBalanceRandomness, sourceKeypair.PublicKey, remainingBalanceCiphertext, remainingBalance)

	proofs := &Proofs{
		RemainingBalanceCommitmentValidityProof: remainingBalanceCommitmentValidityProof,
		SenderTransferAmountLoValidityProof:     sourceCiphertextAmountLoValidityProof,
		SenderTransferAmountHiValidityProof:     sourceCiphertextAmountHiValidityProof,
		RecipientTransferAmountLoValidityProof:  destinationCipherAmountLoValidityProof,
		RecipientTransferAmountHiValidityProof:  destinationCipherAmountHiValidityProof,
	}

	transferProofs := &TransferProofs{}
	proofsProto := transferProofs.ToProto(proofs)
	address1 := sdk.AccAddress("address1")
	address2 := sdk.AccAddress("address2")

	m := &MsgTransfer{
		FromAddress:        address1.String(),
		ToAddress:          address2.String(),
		Denom:              testDenom,
		FromAmountLo:       fromAmountLo,
		FromAmountHi:       fromAmountHi,
		ToAmountLo:         destinationAmountLo,
		ToAmountHi:         destinationAmountHi,
		RemainingBalance:   remainingBalanceProto,
		DecryptableBalance: "sdfsdf",
		Proofs:             proofsProto,
	}

	assert.NoError(t, m.ValidateBasic())

	result, err := m.FromProto()

	assert.NoError(t, err)
	assert.Equal(t, m.ToAddress, result.ToAddress)
	assert.Equal(t, m.FromAddress, result.FromAddress)
	assert.Equal(t, m.Denom, result.Denom)
	assert.Equal(t, m.DecryptableBalance, result.DecryptableBalance)
	assert.True(t, sourceCiphertextAmountLo.C.Equal(result.SenderTransferAmountLo.C))
	assert.True(t, sourceCiphertextAmountLo.D.Equal(result.SenderTransferAmountLo.D))
	assert.True(t, sourceCiphertextAmountHi.C.Equal(result.SenderTransferAmountHi.C))
	assert.True(t, sourceCiphertextAmountHi.D.Equal(result.SenderTransferAmountHi.D))
	assert.True(t, destinationCipherAmountLo.C.Equal(result.RecipientTransferAmountLo.C))
	assert.True(t, destinationCipherAmountLo.D.Equal(result.RecipientTransferAmountLo.D))
	assert.True(t, destinationCipherAmountHi.C.Equal(result.RecipientTransferAmountHi.C))
	assert.True(t, destinationCipherAmountHi.D.Equal(result.RecipientTransferAmountHi.D))
	assert.True(t, remainingBalanceCiphertext.C.Equal(result.RemainingBalanceCommitment.C))
	assert.True(t, remainingBalanceCiphertext.D.Equal(result.RemainingBalanceCommitment.D))

	// Make sure the proofs are valid
	assert.True(t, zkproofs.VerifyCiphertextValidity(
		result.Proofs.SenderTransferAmountLoValidityProof,
		sourceKeypair.PublicKey,
		result.SenderTransferAmountLo))

	assert.True(t, zkproofs.VerifyCiphertextValidity(
		result.Proofs.SenderTransferAmountHiValidityProof,
		sourceKeypair.PublicKey,
		result.SenderTransferAmountHi))

	assert.True(t, zkproofs.VerifyCiphertextValidity(
		result.Proofs.RecipientTransferAmountLoValidityProof,
		destinationKeypair.PublicKey,
		result.RecipientTransferAmountLo))

	assert.True(t, zkproofs.VerifyCiphertextValidity(
		result.Proofs.RecipientTransferAmountHiValidityProof,
		destinationKeypair.PublicKey,
		result.RecipientTransferAmountHi))
}

func TestMsgTr(t *testing.T) {
	testDenom := "factory/sei1ft98au55a24vnu9tvd92cz09pzcfqkm5vlx99w/TEST"
	sourcePrivateKey, _ := elgamal.GenerateKey()
	destPrivateKey, _ := elgamal.GenerateKey()

	eg := elgamal.NewTwistedElgamal()
	sourceKeypair, _ := eg.KeyGen(*sourcePrivateKey, testDenom)
	destinationKeypair, _ := eg.KeyGen(*destPrivateKey, testDenom)

	amountLo := uint64(100)
	amountHi := uint64(0)

	remainingBalance := uint64(200)

	// Encrypt the amount using source and destination public keys
	sourceCiphertextAmountLo, sourceCiphertextAmountLoR, _ := eg.Encrypt(sourceKeypair.PublicKey, amountLo)
	sourceCiphertextAmountLoValidityProof, _ :=
		zkproofs.NewCiphertextValidityProof(&sourceCiphertextAmountLoR, sourceKeypair.PublicKey, sourceCiphertextAmountLo, amountLo)
	sourceCiphertextAmountHi, sourceCiphertextAmountHiR, _ := eg.Encrypt(sourceKeypair.PublicKey, amountHi)
	sourceCiphertextAmountHiValidityProof, _ :=
		zkproofs.NewCiphertextValidityProof(&sourceCiphertextAmountHiR, sourceKeypair.PublicKey, sourceCiphertextAmountHi, amountHi)

	destinationCipherAmountLo, destinationCipherAmountLoR, _ := eg.Encrypt(destinationKeypair.PublicKey, amountLo)
	destinationCipherAmountLoValidityProof, err :=
		zkproofs.NewCiphertextValidityProof(&destinationCipherAmountLoR, destinationKeypair.PublicKey, destinationCipherAmountLo, amountLo)
	destinationCipherAmountHi, destinationCipherAmountHiR, _ := eg.Encrypt(destinationKeypair.PublicKey, amountHi)
	destinationCipherAmountHiValidityProof, err :=
		zkproofs.NewCiphertextValidityProof(&destinationCipherAmountHiR, destinationKeypair.PublicKey, destinationCipherAmountHi, amountHi)

	remainingBalanceCiphertext, remainingBalanceRandomness, _ := eg.Encrypt(sourceKeypair.PublicKey, remainingBalance)
	remainingBalanceCommitmentValidityProof, err :=
		zkproofs.NewCiphertextValidityProof(&remainingBalanceRandomness, sourceKeypair.PublicKey, remainingBalanceCiphertext, remainingBalance)

	proofs := &Proofs{
		RemainingBalanceCommitmentValidityProof: remainingBalanceCommitmentValidityProof,
		SenderTransferAmountLoValidityProof:     sourceCiphertextAmountLoValidityProof,
		SenderTransferAmountHiValidityProof:     sourceCiphertextAmountHiValidityProof,
		RecipientTransferAmountLoValidityProof:  destinationCipherAmountLoValidityProof,
		RecipientTransferAmountHiValidityProof:  destinationCipherAmountHiValidityProof,
	}

	address1 := sdk.AccAddress("address1")
	address2 := sdk.AccAddress("address2")

	fromAmountLo, err := json.Marshal(sourceCiphertextAmountLo)
	assert.NoError(t, err)
	fromAmountHi, err := json.Marshal(sourceCiphertextAmountHi)
	assert.NoError(t, err)
	destinationAmountLo, err := json.Marshal(destinationCipherAmountLo)
	assert.NoError(t, err)
	destinationAmountHi, err := json.Marshal(destinationCipherAmountHi)
	assert.NoError(t, err)

	remainingBalanceBytes, err := json.Marshal(remainingBalanceCiphertext)

	proof, err := json.Marshal(proofs)
	assert.NoError(t, err)

	m := &MsgTr{
		FromAddress:        address1.String(),
		ToAddress:          address2.String(),
		Denom:              testDenom,
		FromAmountLo:       fromAmountLo,
		FromAmountHi:       fromAmountHi,
		ToAmountLo:         destinationAmountLo,
		ToAmountHi:         destinationAmountHi,
		RemainingBalance:   remainingBalanceBytes,
		DecryptableBalance: "sdfsdf",
		Proofs:             proof,
	}

	marshalled, err := json.Marshal(m)
	assert.NoError(t, err)

	var result MsgTr

	err = json.Unmarshal(marshalled, &result)
	assert.NoError(t, err)

	var fromAmountLoCt elgamal.Ciphertext
	err = json.Unmarshal(result.FromAmountLo, &fromAmountLoCt)
	assert.NoError(t, err)

	var fromAmountHiCt elgamal.Ciphertext
	err = json.Unmarshal(result.FromAmountHi, &fromAmountHiCt)
	assert.NoError(t, err)

	var toAmountLoCt elgamal.Ciphertext
	err = json.Unmarshal(result.ToAmountLo, &toAmountLoCt)
	assert.NoError(t, err)

	var toAmountHiCt elgamal.Ciphertext
	err = json.Unmarshal(result.ToAmountHi, &toAmountHiCt)
	assert.NoError(t, err)

	var remainingBalanceCt elgamal.Ciphertext
	err = json.Unmarshal(result.RemainingBalance, &remainingBalanceCt)
	assert.NoError(t, err)

	assert.Equal(t, m.ToAddress, result.ToAddress)
	assert.Equal(t, m.FromAddress, result.FromAddress)
	assert.Equal(t, m.Denom, result.Denom)
	assert.Equal(t, m.DecryptableBalance, result.DecryptableBalance)
	assert.True(t, sourceCiphertextAmountLo.C.Equal(fromAmountLoCt.C))
	assert.True(t, sourceCiphertextAmountLo.D.Equal(fromAmountLoCt.D))
	assert.True(t, sourceCiphertextAmountHi.C.Equal(fromAmountHiCt.C))
	assert.True(t, sourceCiphertextAmountHi.D.Equal(fromAmountHiCt.D))
	assert.True(t, destinationCipherAmountLo.C.Equal(toAmountLoCt.C))
	assert.True(t, destinationCipherAmountLo.D.Equal(toAmountLoCt.D))
	assert.True(t, destinationCipherAmountHi.C.Equal(toAmountHiCt.C))
	assert.True(t, destinationCipherAmountHi.D.Equal(toAmountHiCt.D))
	assert.True(t, remainingBalanceCiphertext.C.Equal(remainingBalanceCt.C))
	assert.True(t, remainingBalanceCiphertext.D.Equal(remainingBalanceCt.D))

	var resultProofs Proofs
	err = json.Unmarshal(result.Proofs, &resultProofs)
	assert.NoError(t, err)

	// Make sure the proofs are valid
	assert.True(t, zkproofs.VerifyCiphertextValidity(
		resultProofs.SenderTransferAmountLoValidityProof,
		sourceKeypair.PublicKey,
		&fromAmountLoCt))

	assert.True(t, zkproofs.VerifyCiphertextValidity(
		resultProofs.SenderTransferAmountHiValidityProof,
		sourceKeypair.PublicKey,
		&fromAmountHiCt))

	assert.True(t, zkproofs.VerifyCiphertextValidity(
		resultProofs.RecipientTransferAmountLoValidityProof,
		destinationKeypair.PublicKey,
		&toAmountLoCt))

	assert.True(t, zkproofs.VerifyCiphertextValidity(
		resultProofs.RecipientTransferAmountHiValidityProof,
		destinationKeypair.PublicKey,
		&toAmountHiCt))
}
