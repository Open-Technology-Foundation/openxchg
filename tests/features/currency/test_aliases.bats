#!/usr/bin/env bats
#
# test_aliases.bats - Test currency alias normalization
#
# Tests the normalize_currency_code() function and alias support

load '../../test_helper.bash'

setup() {
  setup_test_env
  enable_mock_api
}

teardown() {
  teardown_test_env
}

@test "alias: yuan normalizes to CNY" {
  run_openxchg -q -l IDR yuan
  assert_success
  assert_output --partial "CNY"
}

@test "alias: yen normalizes to JPY" {
  run_openxchg -q -l IDR yen
  assert_success
  assert_output --partial "JPY"
}

@test "alias: sterling normalizes to GBP" {
  run_openxchg -q -l IDR sterling
  assert_success
  assert_output --partial "GBP"
}

@test "alias: pound normalizes to GBP" {
  run_openxchg -q -l IDR pound
  assert_success
  assert_output --partial "GBP"
}

@test "alias: dollar normalizes to USD" {
  run_openxchg -q -l IDR dollar
  assert_success
  assert_output --partial "USD"
}

@test "alias: greenback normalizes to USD" {
  run_openxchg -q -l IDR greenback
  assert_success
  assert_output --partial "USD"
}

@test "alias: franc normalizes to CHF" {
  run_openxchg -q -l IDR franc
  assert_success
  assert_output --partial "CHF"
}

@test "alias: swissy normalizes to CHF" {
  run_openxchg -q -l IDR swissy
  assert_success
  assert_output --partial "CHF"
}

@test "alias: aussie normalizes to AUD" {
  run_openxchg -q -l IDR aussie
  assert_success
  assert_output --partial "AUD"
}

@test "alias: kiwi normalizes to NZD" {
  run_openxchg -q -l IDR kiwi
  assert_success
  assert_output --partial "NZD"
}

@test "alias: loonie normalizes to CAD" {
  run_openxchg -q -l IDR loonie
  assert_success
  assert_output --partial "CAD"
}

@test "alias: rupiah normalizes to IDR" {
  run_openxchg -q -l USD rupiah
  assert_success
  assert_output --partial "IDR"
}

@test "alias: rmb normalizes to CNY" {
  run_openxchg -q -l IDR rmb
  assert_success
  assert_output --partial "CNY"
}

@test "alias: renminbi normalizes to CNY" {
  run_openxchg -q -l IDR renminbi
  assert_success
  assert_output --partial "CNY"
}

@test "alias: case-insensitive (YUAN, Yuan, yuan)" {
  run_openxchg -q -l IDR YUAN
  assert_success
  assert_output --partial "CNY"

  run_openxchg -q -l IDR Yuan
  assert_success
  assert_output --partial "CNY"

  run_openxchg -q -l IDR yuan
  assert_success
  assert_output --partial "CNY"
}

@test "alias: 3-letter codes pass through unchanged" {
  run_openxchg -q -l IDR EUR
  assert_success
  assert_output --partial "EUR"

  run_openxchg -q -l IDR USD
  assert_success
  assert_output --partial "USD"
}

@test "alias: mixed aliases and codes in single query" {
  run_openxchg -q -l IDR yuan yen EUR dollar
  assert_success
  assert_output --partial "CNY"
  assert_output --partial "JPY"
  assert_output --partial "EUR"
  assert_output --partial "USD"
}

#fin
