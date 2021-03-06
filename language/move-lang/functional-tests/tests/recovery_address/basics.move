//! account: parent1, 0, 0, address
//! account: child1, 0, 0, address
//! account: child2, 0, 0, address
//! account: parent2, 0, 0, address

//! account: vasp1, 0, 0, address
//! account: vasp2, 0, 0, address

// === Setup ===

// create parent VASP accounts for parent1 and 2
// create a parent VASP
//! new-transaction
//! sender: libraroot
script {
use 0x1::LBR::LBR;
use 0x1::LibraAccount;
fun main(lr_account: &signer) {
    let pubkey = x"7013b6ed7dde3cfb1251db1b04ae9cd7853470284085693590a75def645a926d";
    let add_all_currencies = false;

    LibraAccount::create_parent_vasp_account<LBR>(
        lr_account,
        {{parent1}},
        {{parent1::auth_key}},
        x"A1",
        x"A2",
        copy pubkey,
        add_all_currencies,
    );

    LibraAccount::create_parent_vasp_account<LBR>(
        lr_account,
        {{parent2}},
        {{parent2::auth_key}},
        x"B1",
        x"B2",
        pubkey,
        add_all_currencies,
    );

}
}
// check: EXECUTED

// create two children for parent1
//! new-transaction
//! sender: parent1
script {
use 0x1::LBR::LBR;
use 0x1::LibraAccount;
fun main(account: &signer) {
    LibraAccount::create_child_vasp_account<LBR>(account, {{child1}}, {{child1::auth_key}}, false);
    LibraAccount::create_child_vasp_account<LBR>(account, {{child2}}, {{child2::auth_key}}, false)
}
}
// check: EXECUTED

// === Intended usage ===

// make child1 a recovery address
//! new-transaction
//! sender: child1
script {
use 0x1::LibraAccount;
use 0x1::RecoveryAddress;
fun main(account: &signer) {
    RecoveryAddress::publish(account, LibraAccount::extract_key_rotation_capability(account))
}
}
// check: EXECUTED

// delegate parent1's key to child1
//! new-transaction
//! sender: parent1
script {
use 0x1::LibraAccount;
use 0x1::RecoveryAddress;
fun main(account: &signer) {
    RecoveryAddress::add_rotation_capability(
        LibraAccount::extract_key_rotation_capability(account), {{child1}}
    );
}
}
// check: EXECUTED

// ==== Abort cases ===

// delegating parent2's key to child1 should abort because they are different VASPs
//! new-transaction
//! sender: parent2
script {
use 0x1::LibraAccount;
use 0x1::RecoveryAddress;
fun main(account: &signer) {
    RecoveryAddress::add_rotation_capability(
        LibraAccount::extract_key_rotation_capability(account), {{child1}}
    )
}
}
// check: "ABORTED { code: 3,"

// delegating parent2's key to an account without a RecoveryAddress resource should abort
//! new-transaction
//! sender: parent2
script {
use 0x1::LibraAccount;
use 0x1::RecoveryAddress;
fun main(account: &signer) {
    RecoveryAddress::add_rotation_capability(
        LibraAccount::extract_key_rotation_capability(account), 0x3333
    )
}
}
// check: "ABORTED { code: 5,"

// trying to recover an account that hasn't delegated its KeyRotationCapability to a recovery
// address should abort
//! new-transaction
//! sender: child2
script {
use 0x1::RecoveryAddress;
fun main(account: &signer) {
    let dummy_auth_key = x"7013b6ed7dde3cfb1251db1b04ae9cd7853470284085693590a75def645a926d";
    RecoveryAddress::rotate_authentication_key(account, {{child1}}, {{child2}}, dummy_auth_key);
}
}
// check: "ABORTED { code: 4,"

// trying to recover from an account without a RecoveryAddress resource should abort
//! new-transaction
//! sender: child1
script {
use 0x1::RecoveryAddress;
fun main(account: &signer) {
    let dummy_auth_key = x"7013b6ed7dde3cfb1251db1b04ae9cd7853470284085693590a75def645a926d";
    RecoveryAddress::rotate_authentication_key(account, {{child2}}, {{child1}}, dummy_auth_key);
}
}
// check: "ABORTED { code: 5,"


// parent1 shouldn't be able to rotate child1's address
//! new-transaction
//! sender: parent1
script {
use 0x1::RecoveryAddress;
fun main(account: &signer) {
    let dummy_auth_key = x"7013b6ed7dde3cfb1251db1b04ae9cd7853470284085693590a75def645a926d";
    RecoveryAddress::rotate_authentication_key(account, {{child1}}, {{child1}}, dummy_auth_key);
}
}
// check: "ABORTED { code: 2,"

// A non-vasp can't create a recovery address
//! new-transaction
//! sender: blessed
script {
use 0x1::RecoveryAddress;
use 0x1::LibraAccount;
fun main(account: &signer) {
    RecoveryAddress::publish(account, LibraAccount::extract_key_rotation_capability(account))
}
}
// check: "ABORTED { code: 0,"

//! new-transaction
module Holder {
    resource struct Holder<T> { x: T }
    public fun hold<T>(account: &signer, x: T) {
        move_to(account, Holder<T> { x });
    }

    public fun get<T>(addr: address): T
    acquires Holder {
        let Holder<T>{ x } = move_from<Holder<T>>(addr);
        x
    }
}

//! new-transaction
//! sender: libraroot
//! type-args: 0x1::Coin1::Coin1
//! args: 0, {{vasp1}}, {{vasp1::auth_key}}, b"bob", b"boburl", x"7013b6ed7dde3cfb1251db1b04ae9cd7853470284085693590a75def645a926d", true
stdlib_script::create_parent_vasp_account
// check: EXECUTED

//! new-transaction
//! sender: libraroot
//! type-args: 0x1::Coin1::Coin1
//! args: 0, {{vasp2}}, {{vasp2::auth_key}}, b"bob", b"boburl", x"7013b6ed7dde3cfb1251db1b04ae9cd7853470284085693590a75def645a926d", true
stdlib_script::create_parent_vasp_account
// check: EXECUTED

//! new-transaction
//! sender: vasp1
script {
use {{default}}::Holder;
use 0x1::LibraAccount;
fun main(account: &signer) {
    Holder::hold(account, LibraAccount::extract_key_rotation_capability(account));
}
}
// check: EXECUTED

// Try to create a recovery address with an invalid key rotation capability
//! new-transaction
//! sender: vasp2
script {
use 0x1::RecoveryAddress;
use {{default}}::Holder;
use 0x1::LibraAccount;
fun main(account: &signer) {
    let cap = Holder::get<LibraAccount::KeyRotationCapability>({{vasp1}});
    RecoveryAddress::publish(account, cap);
}
}
// check: "ABORTED { code: 1,"
