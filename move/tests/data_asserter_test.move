#[test_only]
module truthbound_addr::truthbound_test {

    use truthbound_addr::escalation_manager;
    use truthbound_addr::data_asserter;
    use truthbound_addr::oracle_token;

    use std::bcs;
    use std::vector;
    use std::signer;
    use std::option::{Self, Option};

    use aptos_std::smart_table::{SmartTable};

    use aptos_framework::timestamp;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::{Metadata};
    use aptos_framework::event::{ was_event_emitted };

    // -----------------------------------
    // Errors
    // -----------------------------------

    const ERROR_NOT_ADMIN : u64                             = 1;
    const ERROR_ASSERT_IS_BLOCKED: u64                      = 2;
    const ERROR_NOT_WHITELISTED_ASSERTER: u64               = 3;
    const ERROR_NOT_WHITELISTED_DISPUTER: u64               = 4;
    const ERROR_BURNED_BOND_PERCENTAGE_EXCEEDS_HUNDRED: u64 = 5;
    const ERROR_BURNED_BOND_PERCENTAGE_IS_ZERO: u64         = 6;
    const ERROR_ASSERTION_IS_EXPIRED: u64                   = 7;
    const ERROR_ASSERTION_ALREADY_DISPUTED: u64             = 8;
    const ERROR_MINIMUM_BOND_NOT_REACHED: u64               = 9;
    const ERROR_MINIMUM_LIVENESS_NOT_REACHED: u64           = 10;
    const ERROR_ASSERTION_ALREADY_SETTLED: u64              = 11;
    const ERROR_ASSERTION_NOT_EXPIRED: u64                  = 12;
    const ERROR_ASSERTION_ALREADY_EXISTS: u64               = 13;

    // -----------------------------------
    // Constants
    // -----------------------------------

    // note: we use numerical true/false since UMA oracle/escalation_manager may return price data if required
    const NUMERICAL_TRUE: u8                    = 1; // Numerical representation of true
    const NUMERICAL_FALSE: u8                   = 0;        // Numerical representation of false.

    const DEFAULT_ASSERTION_LIVENESS: u64       = 7200;
    const DEFAULT_IDENTIFIER: vector<u8>        = b"ASSERT_TRUTH";

    const DEFAULT_MIN_LIVENESS: u64             = 3600;
    const DEFAULT_FEE: u64                      = 1000;
    const DEFAULT_BURNED_BOND_PERCENTAGE: u64   = 100; // 1%
    const DEFAULT_TREASURY_ADDRESS: address     = @truthbound_addr;

    // -----------------------------------
    // Structs
    // -----------------------------------

    /// DataAssertion Struct
    struct DataAssertion has key, store, drop {
        data_id: vector<u8>,     // The dataId that was asserted.
        data: vector<u8>,        // This could be an arbitrary data type.
        asserter: address,       // The address that made the assertion.
        resolved: bool,          // Whether the assertion has been resolved.
    }

    /// AssertionsData Struct
    struct AssertionsData has key, store {
        assertions_data_table: SmartTable<u64, DataAssertion>,
    }

    /// Assertion Struct
    struct Assertion has key, store {
        asserter: address,
        settled: bool,
        settlement_resolution: bool,
        liveness: u64,
        assertion_time: u64,
        expiration_time: u64,
        identifier: vector<u8>,
        bond: u64,
        disputer: Option<address>
    }

    struct AssertionTable has key, store {
        assertions: SmartTable<u64, Assertion> // assertion_id: vector<u8>
    }

    struct AssertionRegistry has key, store {
        assertion_to_asserter: SmartTable<u64, address>,
        next_assertion_id: u64
    }

    /// AdminProperties Struct 
    struct AdminProperties has key, store {
        default_fee: u64,
        burned_bond_percentage: u128,
        min_liveness: u64,
        treasury_address: address,
        currency_metadata: option::Option<Object<Metadata>>,
    }

    // Oracle Struct
    struct OracleSigner has key, store {
        extend_ref : object::ExtendRef,
    }

    // AdminInfo Struct
    struct AdminInfo has key {
        admin_address: address,
    }

    // -----------------------------------
    // Unit Tests
    // -----------------------------------

    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, user_one = @0x333, user_two = @0x444)]
    public entry fun test_admin_can_set_admin_properties(
        aptos_framework: &signer,
        truthbound: &signer,
        user_one: &signer,
        user_two: &signer,
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, _user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        let oracle_token_metadata   = oracle_token::metadata();
        let min_liveness            = 1000;
        let default_fee             = 100;
        let treasury_addr           = user_one_addr;
        let burned_bond_percentage  = 100;

        // call set_admin_properties
        data_asserter::set_admin_properties(
            truthbound,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );

        // check views
        let (prop_default_fee, prop_burned_bond_percentage, prop_min_liveness, prop_treasury_addr, prop_currency_metadata) = data_asserter::get_admin_properties();
        assert!(prop_min_liveness             == min_liveness           , 100);
        assert!(prop_default_fee              == default_fee            , 101);
        assert!(prop_treasury_addr            == treasury_addr          , 102);
        assert!(prop_burned_bond_percentage   == burned_bond_percentage , 103);
        assert!(prop_currency_metadata        == oracle_token_metadata        , 104);
    }


    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, user_one = @0x333, user_two = @0x444)]
    #[expected_failure(abort_code = ERROR_NOT_ADMIN, location = data_asserter)]
    public entry fun test_non_admin_cannot_set_admin_properties(
        aptos_framework: &signer,
        truthbound: &signer,
        user_one: &signer,
        user_two: &signer,
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, _user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        let oracle_token_metadata   = oracle_token::metadata();
        let min_liveness            = 1000;
        let default_fee             = 100;
        let treasury_addr           = user_one_addr;
        let burned_bond_percentage  = 100;

        // call set_admin_properties
        data_asserter::set_admin_properties(
            user_one,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );
    }
    

    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, user_one = @0x333, user_two = @0x444)]
    #[expected_failure(abort_code = ERROR_BURNED_BOND_PERCENTAGE_EXCEEDS_HUNDRED, location = data_asserter)]
    public entry fun test_set_admin_properties_burned_bond_percentage_cannot_exceed_hundred(
        aptos_framework: &signer,
        truthbound: &signer,
        user_one: &signer,
        user_two: &signer,
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, _user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        let oracle_token_metadata   = oracle_token::metadata();
        let min_liveness            = 1000;
        let default_fee             = 100;
        let treasury_addr           = user_one_addr;
        let burned_bond_percentage  = 10000 + 1; // should fail

        // should fail
        data_asserter::set_admin_properties(
            truthbound,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );
    }


    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, user_one = @0x333, user_two = @0x444)]
    #[expected_failure(abort_code = ERROR_BURNED_BOND_PERCENTAGE_IS_ZERO, location = data_asserter)]
    public entry fun test_set_admin_properties_burned_bond_percentage_cannot_be_zero(
        aptos_framework: &signer,
        truthbound: &signer,
        user_one: &signer,
        user_two: &signer,
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, _user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        let oracle_token_metadata   = oracle_token::metadata();
        let min_liveness            = 1000;
        let default_fee             = 100;
        let treasury_addr           = user_one_addr;
        let burned_bond_percentage  = 0; // should fail

        // should fail
        data_asserter::set_admin_properties(
            truthbound,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );
    }


    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, escalation_manager=@escalation_manager_addr, user_one = @0x333, user_two = @0x444)]
    public entry fun test_assert_data_end_to_end_without_dispute(
        aptos_framework: &signer,
        truthbound: &signer,
        escalation_manager: &signer,
        user_one: &signer,
        user_two: &signer,
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup escalation manager
        escalation_manager::setup_test(aptos_framework, escalation_manager, user_one, user_two);
        
        let block_assertion    = false;
        let validate_asserters = false;
        let validate_disputers = true;

        // call set_assertion_policy to set validate_asserters to false
        escalation_manager::set_assertion_policy(
            escalation_manager,
            block_assertion,
            validate_asserters,
            validate_disputers
        );

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        // mint some tokens to user one for bond
        let mint_amount = 100000000;
        oracle_token::mint(truthbound, user_one_addr, mint_amount);

        // setup admin properties
        let oracle_token_metadata   = oracle_token::metadata();
        let treasury_addr           = user_one_addr;
        let min_liveness            = DEFAULT_MIN_LIVENESS;
        let default_fee             = DEFAULT_FEE;
        let burned_bond_percentage  = DEFAULT_BURNED_BOND_PERCENTAGE;

        // call set_admin_properties
        data_asserter::set_admin_properties(
            truthbound,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );

        // get next assertion id
        let assertion_id = data_asserter::get_next_assertion_id();

        let data_id     = b"weather_forecast_tomorrow";
        let data        = b"sunny";

        // get data view before asserting data
        let ( 
            view_data_bool,
            view_data
        ) = data_asserter::get_data(assertion_id);
        assert!(view_data_bool == false              , 96);
        assert!(view_data      == vector::empty<u8>(), 97);

        // call assert_data_for
        data_asserter::assert_data_for(
            user_one,
            data_id,
            data
        );

        // get data view
        let ( 
            view_data_bool,
            view_data
        ) = data_asserter::get_data(assertion_id);
        assert!(view_data_bool == false              , 98);
        assert!(view_data      == vector::empty<u8>(), 99);

        // bond is transferred from asserter to module
        let bond             = (DEFAULT_FEE * 10000) / DEFAULT_BURNED_BOND_PERCENTAGE;
        let asserter_balance = primary_fungible_store::balance(user_one_addr, oracle_token_metadata);
        assert!(asserter_balance == mint_amount - bond, 100);

        // fast forward to liveness over (after assertion has expired)
        timestamp::fast_forward_seconds(DEFAULT_MIN_LIVENESS + 1);

        // anyone can settle the assertion
        data_asserter::settle_assertion(
            user_two,
            assertion_id
        );

        // get asserter balance after assertion settled
        let updated_asserter_balance = primary_fungible_store::balance(user_one_addr, oracle_token_metadata);

        // asserter should have his bond returned
        assert!(updated_asserter_balance == asserter_balance + bond, 101);

        // get views to confirm assertion has been resolved
        let (
            _asserter, 
            settled, 
            settlement_resolution, 
            _liveness, 
            _assertion_time, 
            _expiration_time, 
            _identifier, 
            _bond, 
            _disputer
        ) = data_asserter::get_assertion(assertion_id);

        assert!(settled                 == true, 102);
        assert!(settlement_resolution   == true, 103);

        // create instance of expected event
        let assertion_settled_event = data_asserter::test_AssertionSettledEvent(
            assertion_id,
            user_one_addr,          // asserter is the bond recipient
            false,                  // disputed
            settlement_resolution,
            user_two_addr           // settle_caller
        );

        // verify if expected event was emitted
        assert!(was_event_emitted(&assertion_settled_event), 104);

        // get data view after resolution
        let ( 
            view_resolved_data_bool,
            view_resolved_data
        ) = data_asserter::get_data(assertion_id);
        assert!(view_resolved_data_bool == true     , 105);
        assert!(view_resolved_data      == data     , 106);

    }


    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, escalation_manager=@escalation_manager_addr, user_one = @0x333, user_two = @0x444, treasury = @0x555)]
    public entry fun test_assert_data_end_to_end_with_dispute_and_asserter_wins(
        aptos_framework: &signer,
        truthbound: &signer,
        escalation_manager: &signer,
        user_one: &signer,
        user_two: &signer,
        treasury: &signer
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup escalation manager
        escalation_manager::setup_test(aptos_framework, escalation_manager, user_one, user_two);
        
        let block_assertion    = false;
        let validate_asserters = false;
        let validate_disputers = false;

        // set assertion policy
        escalation_manager::set_assertion_policy(
            escalation_manager,
            block_assertion,
            validate_asserters,
            validate_disputers
        );

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        // mint some tokens to user one (asserter), user two (disputer), and treasury
        let mint_amount   = 100000000;
        let treasury_addr = signer::address_of(treasury);
        oracle_token::mint(truthbound, user_one_addr, mint_amount);
        oracle_token::mint(truthbound, user_two_addr, mint_amount);
        oracle_token::mint(truthbound, treasury_addr, mint_amount);

        // setup admin properties
        let oracle_token_metadata   = oracle_token::metadata();
        let treasury_addr           = treasury_addr;
        let min_liveness            = DEFAULT_MIN_LIVENESS;
        let default_fee             = DEFAULT_FEE;
        let burned_bond_percentage  = DEFAULT_BURNED_BOND_PERCENTAGE;

        // call set_admin_properties
        data_asserter::set_admin_properties(
            truthbound,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );

        // get next assertion id
        let assertion_id = data_asserter::get_next_assertion_id();

        let data_id     = b"weather_forecast_tomorrow";
        let data        = b"sunny";

        // call assert_data_for
        data_asserter::assert_data_for(
            user_one,
            data_id,
            data
        );

        // user two disputes assertion
        data_asserter::dispute_assertion(
            user_two,
            assertion_id
        );

        // bond is transferred from disputer to module
        let bond             = (DEFAULT_FEE * 10000) / DEFAULT_BURNED_BOND_PERCENTAGE;
        let disputer_balance = primary_fungible_store::balance(user_two_addr, oracle_token_metadata);
        assert!(disputer_balance == mint_amount - bond, 100);

        // create instance of expected event
        let assertion_disputed_event = data_asserter::test_AssertionDisputedEvent(
            assertion_id,
            user_two_addr // disputer
        );

        // verify if expected event was emitted
        assert!(was_event_emitted(&assertion_disputed_event), 101);

        // get views to confirm assertion has been updated with disputer
        let (
            _asserter, 
            _settled, 
            _settlement_resolution, 
            _liveness, 
            assertion_time, 
            _expiration_time, 
            _identifier, 
            _bond, 
            disputer
        ) = data_asserter::get_assertion(assertion_id);

        assert!(option::destroy_some(disputer) == user_two_addr, 102);

        // set arbitration resolution parameters
        let time                    = bcs::to_bytes<u64>(&assertion_time); 
        let ancillary_data          = data_asserter::stamp_assertion(assertion_id, user_one_addr);
        let arbitration_resolution  = true; // asserter wins
        let override                = false;

        // escalation manager to resolve the dispute
        escalation_manager::set_arbitration_resolution(
            escalation_manager,
            time,
            DEFAULT_IDENTIFIER,
            ancillary_data,
            arbitration_resolution,
            override
        );

        // fast forward to liveness over (after assertion has expired)
        timestamp::fast_forward_seconds(DEFAULT_MIN_LIVENESS + 1);

        // get asserter, disputer, and treasury balance before assertion settled
        let initial_asserter_balance = primary_fungible_store::balance(user_one_addr, oracle_token_metadata);
        let initial_disputer_balance = primary_fungible_store::balance(user_two_addr, oracle_token_metadata);
        let initial_treasury_balance = primary_fungible_store::balance(treasury_addr, oracle_token_metadata);

        // anyone can settle the assertion
        data_asserter::settle_assertion(
            user_one,
            assertion_id
        );

        // get views to confirm assertion has been settled
        let (
            _asserter, 
            settled, 
            settlement_resolution, 
            _liveness, 
            _assertion_time, 
            _expiration_time, 
            _identifier, 
            bond, 
            _disputer
        ) = data_asserter::get_assertion(assertion_id);

        assert!(settled                 == true, 103);
        assert!(settlement_resolution   == arbitration_resolution, 104);

        // get asserter, disputer, and treasury balance after assertion settled
        let updated_asserter_balance = primary_fungible_store::balance(user_one_addr, oracle_token_metadata);
        let updated_disputer_balance = primary_fungible_store::balance(user_two_addr, oracle_token_metadata);
        let updated_treasury_balance = primary_fungible_store::balance(treasury_addr, oracle_token_metadata);

        // calculate fee 
        let oracle_fee            = (burned_bond_percentage * bond) / 10000;
        let bond_recipient_amount = (bond * 2) - oracle_fee;

        // asserter should receive his bond + disputer bond less oracle fee
        assert!(updated_asserter_balance == initial_asserter_balance + bond_recipient_amount, 105);

        // treasury should receive oracle fee
        assert!(updated_treasury_balance == initial_treasury_balance + oracle_fee, 106);

        // no changes to disputer balance as he lost the dispute
        assert!(updated_disputer_balance == initial_disputer_balance, 107);

        // create instance of expected event
        let assertion_settled_event = data_asserter::test_AssertionSettledEvent(
            assertion_id,
            user_one_addr,          // asserter is the bond recipient
            true,                   // disputed
            settlement_resolution,
            user_one_addr           // settle_caller
        );

        // verify if expected event was emitted
        assert!(was_event_emitted(&assertion_settled_event), 108);
    }


    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, escalation_manager=@escalation_manager_addr, user_one = @0x333, user_two = @0x444, treasury = @0x555)]
    public entry fun test_assert_data_end_to_end_with_dispute_and_disputer_wins(
        aptos_framework: &signer,
        truthbound: &signer,
        escalation_manager: &signer,
        user_one: &signer,
        user_two: &signer,
        treasury: &signer
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup escalation manager
        escalation_manager::setup_test(aptos_framework, escalation_manager, user_one, user_two);
        
        let block_assertion    = false;
        let validate_asserters = false;
        let validate_disputers = false;

        // set assertion policy
        escalation_manager::set_assertion_policy(
            escalation_manager,
            block_assertion,
            validate_asserters,
            validate_disputers
        );

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        // mint some tokens to user one (asserter), user two (disputer), and treasury
        let mint_amount   = 100000000;
        let treasury_addr = signer::address_of(treasury);
        oracle_token::mint(truthbound, user_one_addr, mint_amount);
        oracle_token::mint(truthbound, user_two_addr, mint_amount);
        oracle_token::mint(truthbound, treasury_addr, mint_amount);

        // setup admin properties
        let oracle_token_metadata   = oracle_token::metadata();
        let treasury_addr           = treasury_addr;
        let min_liveness            = DEFAULT_MIN_LIVENESS;
        let default_fee             = DEFAULT_FEE;
        let burned_bond_percentage  = DEFAULT_BURNED_BOND_PERCENTAGE;

        // call set_admin_properties
        data_asserter::set_admin_properties(
            truthbound,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );

        // get next assertion id
        let assertion_id = data_asserter::get_next_assertion_id();

        let data_id     = b"weather_forecast_tomorrow";
        let data        = b"sunny";

        // call assert_data_for
        data_asserter::assert_data_for(
            user_one,
            data_id,
            data
        );

        // user two disputes assertion
        data_asserter::dispute_assertion(
            user_two,
            assertion_id
        );

        // bond is transferred from disputer to module
        let bond             = (DEFAULT_FEE * 10000) / DEFAULT_BURNED_BOND_PERCENTAGE;
        let disputer_balance = primary_fungible_store::balance(user_two_addr, oracle_token_metadata);
        assert!(disputer_balance == mint_amount - bond, 100);

        // create instance of expected event
        let assertion_disputed_event = data_asserter::test_AssertionDisputedEvent(
            assertion_id,
            user_two_addr // disputer
        );

        // verify if expected event was emitted
        assert!(was_event_emitted(&assertion_disputed_event), 101);

        // get views to confirm assertion has been updated with disputer
        let (
            _asserter, 
            _settled, 
            _settlement_resolution, 
            _liveness, 
            assertion_time, 
            _expiration_time, 
            _identifier, 
            _bond, 
            disputer
        ) = data_asserter::get_assertion(assertion_id);

        assert!(option::destroy_some(disputer) == user_two_addr, 102);

        // set arbitration resolution parameters
        let time                    = bcs::to_bytes<u64>(&assertion_time); 
        let ancillary_data          = data_asserter::stamp_assertion(assertion_id, user_one_addr);
        let arbitration_resolution  = false; // disputer wins
        let override                = false;

        // escalation manager to resolve the dispute
        escalation_manager::set_arbitration_resolution(
            escalation_manager,
            time,
            DEFAULT_IDENTIFIER,
            ancillary_data,
            arbitration_resolution,
            override
        );

        // fast forward to liveness over (after assertion has expired)
        timestamp::fast_forward_seconds(DEFAULT_MIN_LIVENESS + 1);

        // get asserter, disputer, and treasury balance before assertion settled
        let initial_asserter_balance = primary_fungible_store::balance(user_one_addr, oracle_token_metadata);
        let initial_disputer_balance = primary_fungible_store::balance(user_two_addr, oracle_token_metadata);
        let initial_treasury_balance = primary_fungible_store::balance(treasury_addr, oracle_token_metadata);

        // anyone can settle the assertion
        data_asserter::settle_assertion(
            user_one,
            assertion_id
        );

        // get views to confirm assertion has been settled
        let (
            _asserter, 
            settled, 
            settlement_resolution, 
            _liveness, 
            _assertion_time, 
            _expiration_time, 
            _identifier, 
            bond, 
            _disputer
        ) = data_asserter::get_assertion(assertion_id);

        assert!(settled                 == true, 103);
        assert!(settlement_resolution   == arbitration_resolution, 104);

        // get asserter, disputer, and treasury balance after assertion settled
        let updated_asserter_balance = primary_fungible_store::balance(user_one_addr, oracle_token_metadata);
        let updated_disputer_balance = primary_fungible_store::balance(user_two_addr, oracle_token_metadata);
        let updated_treasury_balance = primary_fungible_store::balance(treasury_addr, oracle_token_metadata);

        // calculate fee 
        let oracle_fee            = (burned_bond_percentage * bond) / 10000;
        let bond_recipient_amount = (bond * 2) - oracle_fee;

        // no changes to asserter balance as he lost the dispute
        assert!(updated_asserter_balance == initial_asserter_balance, 105);

        // treasury should receive oracle fee
        assert!(updated_treasury_balance == initial_treasury_balance + oracle_fee, 106);

        // disputer should receive his bond + asserter bond less oracle fee
        assert!(updated_disputer_balance == initial_disputer_balance + bond_recipient_amount, 107);

        // create instance of expected event
        let assertion_settled_event = data_asserter::test_AssertionSettledEvent(
            assertion_id,
            user_two_addr,          // asserter is the bond recipient
            true,                   // disputed
            settlement_resolution,
            user_one_addr           // settle_caller
        );

        // verify if expected event was emitted
        assert!(was_event_emitted(&assertion_settled_event), 108);
    }



    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, escalation_manager=@escalation_manager_addr, user_one = @0x333, user_two = @0x444)]
    #[expected_failure(abort_code = ERROR_NOT_WHITELISTED_ASSERTER, location = data_asserter)]
    public entry fun test_non_whitelisted_asserters_cannot_call_assert_data_if_validate_asserters_is_true(
        aptos_framework: &signer,
        truthbound: &signer,
        escalation_manager: &signer,
        user_one: &signer,
        user_two: &signer,
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, _user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup escalation manager
        escalation_manager::setup_test(aptos_framework, escalation_manager, user_one, user_two);

        let block_assertion    = false;
        let validate_asserters = true;
        let validate_disputers = false;

        // call set_assertion_policy to set validate_asserters to false
        escalation_manager::set_assertion_policy(
            escalation_manager,
            block_assertion,
            validate_asserters,
            validate_disputers
        );

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        // mint some tokens to user one for bond
        let mint_amount = 100000000;
        oracle_token::mint(truthbound, user_one_addr, mint_amount);

        // setup admin properties
        let oracle_token_metadata   = oracle_token::metadata();
        let treasury_addr           = user_one_addr;
        let min_liveness            = DEFAULT_MIN_LIVENESS;
        let default_fee             = DEFAULT_FEE;
        let burned_bond_percentage  = DEFAULT_BURNED_BOND_PERCENTAGE;

        // call set_admin_properties
        data_asserter::set_admin_properties(
            truthbound,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );

        let data_id     = b"weather_forecast_tomorrow";
        let data        = b"sunny";

        // call assert_data_for
        data_asserter::assert_data_for(
            user_one,
            data_id,
            data
        );

    }


    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, escalation_manager=@escalation_manager_addr, user_one = @0x333, user_two = @0x444)]
    public entry fun test_only_whitelisted_asserters_can_call_assert_data_if_validate_asserters_is_true(
        aptos_framework: &signer,
        truthbound: &signer,
        escalation_manager: &signer,
        user_one: &signer,
        user_two: &signer,
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, _user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup escalation manager
        escalation_manager::setup_test(aptos_framework, escalation_manager, user_one, user_two);

        let block_assertion    = false;
        let validate_asserters = true;
        let validate_disputers = false;

        // call set_assertion_policy to set validate_asserters to false
        escalation_manager::set_assertion_policy(
            escalation_manager,
            block_assertion,
            validate_asserters,
            validate_disputers
        );

        // call set_whitelisted_asserter
        escalation_manager::set_whitelisted_asserter(
            escalation_manager,
            user_one_addr,
            true
        );

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        // mint some tokens to user one for bond
        let mint_amount = 100000000;
        oracle_token::mint(truthbound, user_one_addr, mint_amount);

        // setup admin properties
        let oracle_token_metadata   = oracle_token::metadata();
        let treasury_addr           = user_one_addr;
        let min_liveness            = DEFAULT_MIN_LIVENESS;
        let default_fee             = DEFAULT_FEE;
        let burned_bond_percentage  = DEFAULT_BURNED_BOND_PERCENTAGE;

        // call set_admin_properties
        data_asserter::set_admin_properties(
            truthbound,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );

        let data_id     = b"weather_forecast_tomorrow";
        let data        = b"sunny";

        // call assert_data_for
        data_asserter::assert_data_for(
            user_one,
            data_id,
            data
        );

    }


    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, escalation_manager=@escalation_manager_addr, user_one = @0x333, user_two = @0x444)]
    #[expected_failure(abort_code = ERROR_ASSERT_IS_BLOCKED, location = data_asserter)]
    public entry fun test_user_cannot_assert_data_if_block_assertion_is_true(
        aptos_framework: &signer,
        truthbound: &signer,
        escalation_manager: &signer,
        user_one: &signer,
        user_two: &signer,
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, _user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup escalation manager
        escalation_manager::setup_test(aptos_framework, escalation_manager, user_one, user_two);

        let block_assertion    = true;
        let validate_asserters = false;
        let validate_disputers = false;

        // call set_assertion_policy to set validate_asserters to false
        escalation_manager::set_assertion_policy(
            escalation_manager,
            block_assertion,
            validate_asserters,
            validate_disputers
        );

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        // mint some tokens to user one for bond
        let mint_amount = 100000000;
        oracle_token::mint(truthbound, user_one_addr, mint_amount);

        // setup admin properties
        let oracle_token_metadata   = oracle_token::metadata();
        let treasury_addr           = user_one_addr;
        let min_liveness            = DEFAULT_MIN_LIVENESS;
        let default_fee             = DEFAULT_FEE;
        let burned_bond_percentage  = DEFAULT_BURNED_BOND_PERCENTAGE;

        // call set_admin_properties
        data_asserter::set_admin_properties(
            truthbound,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );

        let data_id     = b"weather_forecast_tomorrow";
        let data        = b"sunny";

        // call assert_data_for
        data_asserter::assert_data_for(
            user_one,
            data_id,
            data
        );

    }


    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, escalation_manager=@escalation_manager_addr, user_one = @0x333, user_two = @0x444)]
    public entry fun test_user_can_assert_data_even_if_the_same_assertion_already_exists(
        aptos_framework: &signer,
        truthbound: &signer,
        escalation_manager: &signer,
        user_one: &signer,
        user_two: &signer,
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, _user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup escalation manager
        escalation_manager::setup_test(aptos_framework, escalation_manager, user_one, user_two);

        let block_assertion    = false;
        let validate_asserters = false;
        let validate_disputers = false;

        // call set_assertion_policy to set validate_asserters to false
        escalation_manager::set_assertion_policy(
            escalation_manager,
            block_assertion,
            validate_asserters,
            validate_disputers
        );

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        // mint some tokens to user one for bond
        let mint_amount = 100000000;
        oracle_token::mint(truthbound, user_one_addr, mint_amount);

        // setup admin properties
        let oracle_token_metadata   = oracle_token::metadata();
        let treasury_addr           = user_one_addr;
        let min_liveness            = DEFAULT_MIN_LIVENESS;
        let default_fee             = DEFAULT_FEE;
        let burned_bond_percentage  = DEFAULT_BURNED_BOND_PERCENTAGE;

        // call set_admin_properties
        data_asserter::set_admin_properties(
            truthbound,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );

        let data_id     = b"weather_forecast_tomorrow";
        let data        = b"sunny";

        // call assert_data_for
        data_asserter::assert_data_for(
            user_one,
            data_id,
            data
        );

        // call assert_data_for
        data_asserter::assert_data_for(
            user_one,
            data_id,
            data
        );

    }

    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, escalation_manager=@escalation_manager_addr, user_one = @0x333, user_two = @0x444, treasury = @0x555)]
    #[expected_failure(abort_code = ERROR_NOT_WHITELISTED_DISPUTER, location = data_asserter)]
    public entry fun test_non_whitelisted_disputers_cannot_dispute_assertions_if_validate_disputers_is_true(
        aptos_framework: &signer,
        truthbound: &signer,
        escalation_manager: &signer,
        user_one: &signer,
        user_two: &signer,
        treasury: &signer
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup escalation manager
        escalation_manager::setup_test(aptos_framework, escalation_manager, user_one, user_two);
        
        let block_assertion    = false;
        let validate_asserters = false;
        let validate_disputers = true;

        // set assertion policy
        escalation_manager::set_assertion_policy(
            escalation_manager,
            block_assertion,
            validate_asserters,
            validate_disputers
        );

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        // mint some tokens to user one (asserter), user two (disputer), and treasury
        let mint_amount   = 100000000;
        let treasury_addr = signer::address_of(treasury);
        oracle_token::mint(truthbound, user_one_addr, mint_amount);
        oracle_token::mint(truthbound, user_two_addr, mint_amount);
        oracle_token::mint(truthbound, treasury_addr, mint_amount);

        // setup admin properties
        let oracle_token_metadata   = oracle_token::metadata();
        let treasury_addr           = treasury_addr;
        let min_liveness            = DEFAULT_MIN_LIVENESS;
        let default_fee             = DEFAULT_FEE;
        let burned_bond_percentage  = DEFAULT_BURNED_BOND_PERCENTAGE;

        // call set_admin_properties
        data_asserter::set_admin_properties(
            truthbound,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );

        // get next assertion id
        let assertion_id = data_asserter::get_next_assertion_id();

        let data_id     = b"weather_forecast_tomorrow";
        let data        = b"sunny";

        // call assert_data_for
        data_asserter::assert_data_for(
            user_one,
            data_id,
            data
        );

        // user two disputes assertion
        data_asserter::dispute_assertion(
            user_two,
            assertion_id
        );
    }


    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, escalation_manager=@escalation_manager_addr, user_one = @0x333, user_two = @0x444, treasury = @0x555)]
    public entry fun test_only_whitelisted_disputers_can_dispute_assertions_if_validate_disputers_is_true(
        aptos_framework: &signer,
        truthbound: &signer,
        escalation_manager: &signer,
        user_one: &signer,
        user_two: &signer,
        treasury: &signer
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup escalation manager
        escalation_manager::setup_test(aptos_framework, escalation_manager, user_one, user_two);
        
        let block_assertion    = false;
        let validate_asserters = false;
        let validate_disputers = true;

        // set assertion policy
        escalation_manager::set_assertion_policy(
            escalation_manager,
            block_assertion,
            validate_asserters,
            validate_disputers
        );

        // call set_whitelisted_dispute_caller
        escalation_manager::set_whitelisted_dispute_caller(
            escalation_manager,
            user_two_addr,
            true
        );

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        // mint some tokens to user one (asserter), user two (disputer), and treasury
        let mint_amount   = 100000000;
        let treasury_addr = signer::address_of(treasury);
        oracle_token::mint(truthbound, user_one_addr, mint_amount);
        oracle_token::mint(truthbound, user_two_addr, mint_amount);
        oracle_token::mint(truthbound, treasury_addr, mint_amount);

        // setup admin properties
        let oracle_token_metadata   = oracle_token::metadata();
        let treasury_addr           = treasury_addr;
        let min_liveness            = DEFAULT_MIN_LIVENESS;
        let default_fee             = DEFAULT_FEE;
        let burned_bond_percentage  = DEFAULT_BURNED_BOND_PERCENTAGE;

        // call set_admin_properties
        data_asserter::set_admin_properties(
            truthbound,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );

        // get next assertion id
        let assertion_id = data_asserter::get_next_assertion_id();

        let data_id     = b"weather_forecast_tomorrow";
        let data        = b"sunny";

        // call assert_data_for
        data_asserter::assert_data_for(
            user_one,
            data_id,
            data
        );

        // user two disputes assertion
        data_asserter::dispute_assertion(
            user_two,
            assertion_id
        );
    }


    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, escalation_manager=@escalation_manager_addr, user_one = @0x333, user_two = @0x444, treasury = @0x555)]
    #[expected_failure(abort_code = ERROR_ASSERTION_IS_EXPIRED, location = data_asserter)]
    public entry fun test_dispute_assertion_cannot_be_called_after_assertion_has_expired(
        aptos_framework: &signer,
        truthbound: &signer,
        escalation_manager: &signer,
        user_one: &signer,
        user_two: &signer,
        treasury: &signer
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup escalation manager
        escalation_manager::setup_test(aptos_framework, escalation_manager, user_one, user_two);
        
        let block_assertion    = false;
        let validate_asserters = false;
        let validate_disputers = false;

        // set assertion policy
        escalation_manager::set_assertion_policy(
            escalation_manager,
            block_assertion,
            validate_asserters,
            validate_disputers
        );

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        // mint some tokens to user one (asserter), user two (disputer), and treasury
        let mint_amount   = 100000000;
        let treasury_addr = signer::address_of(treasury);
        oracle_token::mint(truthbound, user_one_addr, mint_amount);
        oracle_token::mint(truthbound, user_two_addr, mint_amount);
        oracle_token::mint(truthbound, treasury_addr, mint_amount);

        // setup admin properties
        let oracle_token_metadata   = oracle_token::metadata();
        let treasury_addr           = treasury_addr;
        let min_liveness            = DEFAULT_MIN_LIVENESS;
        let default_fee             = DEFAULT_FEE;
        let burned_bond_percentage  = DEFAULT_BURNED_BOND_PERCENTAGE;

        // call set_admin_properties
        data_asserter::set_admin_properties(
            truthbound,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );

        // get next assertion id
        let assertion_id = data_asserter::get_next_assertion_id();

        let data_id     = b"weather_forecast_tomorrow";
        let data        = b"sunny";

        // call assert_data_for
        data_asserter::assert_data_for(
            user_one,
            data_id,
            data
        );

        // fast forward to liveness over (after assertion has expired)
        timestamp::fast_forward_seconds(DEFAULT_MIN_LIVENESS + 1);

        // user two disputes assertion
        data_asserter::dispute_assertion(
            user_two,
            assertion_id
        );
    }


    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, escalation_manager=@escalation_manager_addr, user_one = @0x333, user_two = @0x444, treasury = @0x555)]
    #[expected_failure(abort_code = ERROR_ASSERTION_ALREADY_DISPUTED, location = data_asserter)]
    public entry fun test_assertion_cannot_be_disputed_more_than_once(
        aptos_framework: &signer,
        truthbound: &signer,
        escalation_manager: &signer,
        user_one: &signer,
        user_two: &signer,
        treasury: &signer
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup escalation manager
        escalation_manager::setup_test(aptos_framework, escalation_manager, user_one, user_two);
        
        let block_assertion    = false;
        let validate_asserters = false;
        let validate_disputers = false;

        // set assertion policy
        escalation_manager::set_assertion_policy(
            escalation_manager,
            block_assertion,
            validate_asserters,
            validate_disputers
        );

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        // mint some tokens to user one (asserter), user two (disputer), and treasury
        let mint_amount   = 100000000;
        let treasury_addr = signer::address_of(treasury);
        oracle_token::mint(truthbound, user_one_addr, mint_amount);
        oracle_token::mint(truthbound, user_two_addr, mint_amount);
        oracle_token::mint(truthbound, treasury_addr, mint_amount);

        // setup admin properties
        let oracle_token_metadata   = oracle_token::metadata();
        let treasury_addr           = treasury_addr;
        let min_liveness            = DEFAULT_MIN_LIVENESS;
        let default_fee             = DEFAULT_FEE;
        let burned_bond_percentage  = DEFAULT_BURNED_BOND_PERCENTAGE;

        // call set_admin_properties
        data_asserter::set_admin_properties(
            truthbound,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );

        // get next assertion id
        let assertion_id = data_asserter::get_next_assertion_id();

        let data_id     = b"weather_forecast_tomorrow";
        let data        = b"sunny";

        // call assert_data_for
        data_asserter::assert_data_for(
            user_one,
            data_id,
            data
        );
        
        // user two disputes assertion
        data_asserter::dispute_assertion(
            user_two,
            assertion_id
        );

        // should fail as assertion is already disputed
        data_asserter::dispute_assertion(
            user_two,
            assertion_id
        );
    }


    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, escalation_manager=@escalation_manager_addr, user_one = @0x333, user_two = @0x444, treasury = @0x555)]
    #[expected_failure(abort_code = ERROR_ASSERTION_ALREADY_SETTLED, location = data_asserter)]
    public entry fun test_assertion_cannot_be_settled_more_than_once(
        aptos_framework: &signer,
        truthbound: &signer,
        escalation_manager: &signer,
        user_one: &signer,
        user_two: &signer,
        treasury: &signer
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup escalation manager
        escalation_manager::setup_test(aptos_framework, escalation_manager, user_one, user_two);
        
        let block_assertion    = false;
        let validate_asserters = false;
        let validate_disputers = false;

        // set assertion policy
        escalation_manager::set_assertion_policy(
            escalation_manager,
            block_assertion,
            validate_asserters,
            validate_disputers
        );

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        // mint some tokens to user one (asserter), user two (disputer), and treasury
        let mint_amount   = 100000000;
        let treasury_addr = signer::address_of(treasury);
        oracle_token::mint(truthbound, user_one_addr, mint_amount);
        oracle_token::mint(truthbound, user_two_addr, mint_amount);
        oracle_token::mint(truthbound, treasury_addr, mint_amount);

        // setup admin properties
        let oracle_token_metadata   = oracle_token::metadata();
        let treasury_addr           = treasury_addr;
        let min_liveness            = DEFAULT_MIN_LIVENESS;
        let default_fee             = DEFAULT_FEE;
        let burned_bond_percentage  = DEFAULT_BURNED_BOND_PERCENTAGE;

        // call set_admin_properties
        data_asserter::set_admin_properties(
            truthbound,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );

        // get next assertion id
        let assertion_id = data_asserter::get_next_assertion_id();

        let data_id     = b"weather_forecast_tomorrow";
        let data        = b"sunny";

        // call assert_data_for
        data_asserter::assert_data_for(
            user_one,
            data_id,
            data
        );

        // fast forward to liveness over (after assertion has expired)
        timestamp::fast_forward_seconds(DEFAULT_MIN_LIVENESS + 1);

        // anyone can settle the assertion
        data_asserter::settle_assertion(
            user_two,
            assertion_id
        );

        // should fail as assertion is already settled
        data_asserter::settle_assertion(
            user_two,
            assertion_id
        );
    }


    #[test(aptos_framework = @0x1, truthbound=@truthbound_addr, escalation_manager=@escalation_manager_addr, user_one = @0x333, user_two = @0x444, treasury = @0x555)]
    #[expected_failure(abort_code = ERROR_ASSERTION_NOT_EXPIRED, location = data_asserter)]
    public entry fun test_assertion_cannot_be_settled_before_expiration_time(
        aptos_framework: &signer,
        truthbound: &signer,
        escalation_manager: &signer,
        user_one: &signer,
        user_two: &signer,
        treasury: &signer
    )  {

        // setup environment
        let (_truthbound_addr, user_one_addr, user_two_addr) = data_asserter::setup_test(aptos_framework, truthbound, user_one, user_two);

        // setup escalation manager
        escalation_manager::setup_test(aptos_framework, escalation_manager, user_one, user_two);
        
        let block_assertion    = false;
        let validate_asserters = false;
        let validate_disputers = false;

        // set assertion policy
        escalation_manager::set_assertion_policy(
            escalation_manager,
            block_assertion,
            validate_asserters,
            validate_disputers
        );

        // setup oracle dapp token
        oracle_token::setup_test(truthbound);

        // mint some tokens to user one (asserter), user two (disputer), and treasury
        let mint_amount   = 100000000;
        let treasury_addr = signer::address_of(treasury);
        oracle_token::mint(truthbound, user_one_addr, mint_amount);
        oracle_token::mint(truthbound, user_two_addr, mint_amount);
        oracle_token::mint(truthbound, treasury_addr, mint_amount);

        // setup admin properties
        let oracle_token_metadata   = oracle_token::metadata();
        let treasury_addr           = treasury_addr;
        let min_liveness            = DEFAULT_MIN_LIVENESS;
        let default_fee             = DEFAULT_FEE;
        let burned_bond_percentage  = DEFAULT_BURNED_BOND_PERCENTAGE;

        // call set_admin_properties
        data_asserter::set_admin_properties(
            truthbound,
            oracle_token_metadata,
            min_liveness,
            default_fee,
            treasury_addr,
            burned_bond_percentage
        );

        // get next assertion id
        let assertion_id = data_asserter::get_next_assertion_id();

        let data_id     = b"weather_forecast_tomorrow";
        let data        = b"sunny";

        // call assert_data_for
        data_asserter::assert_data_for(
            user_one,
            data_id,
            data
        );

        // anyone can settle the assertion
        data_asserter::settle_assertion(
            user_two,
            assertion_id
        );

    }
    
}