// import libraries
use contracts::counter::{
    Counter, ICounterDispatcher, ICounterDispatcherTrait, ICounterSafeDispatcher,
    ICounterSafeDispatcherTrait,
};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::EventSpyAssertionsTrait;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, spy_events, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ContractAddress};


const ZERO_COUNT: u32 = 0;

// Test account -> Owner
fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

// Test account -> User
fn USER() -> ContractAddress {
    'USER'.try_into().unwrap()
}

// Amount of STRK to transfer
const STRK_AMOUNT: u256 = 1000;

// util deploy functions
fn __depoly__(init_value: u32) -> (ICounterDispatcher, IOwnableDispatcher, ICounterSafeDispatcher) {
    // declare the contract
    let contract_class = declare("Counter").expect('Failed to declare counter').contract_class();

    // serialize constructor
    let mut calldata: Array<felt252> = array![];

    init_value.serialize(ref calldata);
    OWNER().serialize(ref calldata);

    // deploy the contract
    let (contract_address, _) = contract_class
        .deploy(@calldata)
        .expect('Failed to deploy contract');

    let counter = ICounterDispatcher { contract_address };
    let ownable = IOwnableDispatcher { contract_address };
    let safe_dispatcher = ICounterSafeDispatcher { contract_address };

    (counter, ownable, safe_dispatcher)
}

#[test]
fn test_counter_deployment() {
    // deploy the contract
    let (counter, ownable, _) = __depoly__(ZERO_COUNT);

    // count 1
    let count_1 = counter.get_counter();

    assert(count_1 == ZERO_COUNT, 'Counter not set to 0');
    assert(ownable.owner() == OWNER(), 'Owner not set');
}

#[test]
fn test_increase_state_changes() {
    // deploy the contract
    let (counter, _, _) = __depoly__(ZERO_COUNT);
    let count_1 = counter.get_counter();

    assert(count_1 == ZERO_COUNT, 'Counter not set to 0');

    counter.increase_counter();

    let count_2 = counter.get_counter();

    assert(count_2 == count_1 + 1, 'Counter not increased');
}

#[test]
fn test_increase_emitted_events() {
    // deploy the contract
    let (counter, _, _) = __depoly__(ZERO_COUNT);

    assert(counter.get_counter() == ZERO_COUNT, 'Counter not set to 0');
    let mut spy = spy_events();

    // mock a caller
    start_cheat_caller_address(counter.contract_address, USER());
    counter.increase_counter();
    stop_cheat_caller_address(counter.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Increased(Counter::Increased { account: USER() }),
                ),
            ],
        );

    spy
        .assert_not_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Decreased(Counter::Decreased { account: USER() }),
                ),
            ],
        );
}

#[test]
fn test_increase_emitted_events_and_state_changes() {
    // deploy the contract
    let (counter, _, _) = __depoly__(ZERO_COUNT);
    let count_1 = counter.get_counter();

    assert(count_1 == ZERO_COUNT, 'Counter not set to 0');
    let mut spy = spy_events();

    // mock a caller
    start_cheat_caller_address(counter.contract_address, USER());
    counter.increase_counter();
    stop_cheat_caller_address(counter.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Increased(Counter::Increased { account: USER() }),
                ),
            ],
        );

    spy
        .assert_not_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Decreased(Counter::Decreased { account: USER() }),
                ),
            ],
        );

    let count_2 = counter.get_counter();

    assert(count_2 == count_1 + 1, 'Counter not increased');
}

#[test]
#[feature("safe_dispatcher")]
fn test_safe_panic_counter_decrease() {
    // deploy the contract
    let (counter, _, safe_dispatcher) = __depoly__(ZERO_COUNT);

    assert(counter.get_counter() == 0, 'Counter not 0');

    match safe_dispatcher.decrease_counter() {
        Result::Ok(_) => panic!("Counter decrease 0"),
        Result::Err(e) => assert(*e[0] == 'Decreasing Empty Counter', *e.at(0)),
    }
}

#[test]
#[should_panic(expected: 'Decreasing Empty Counter')]
fn test_panic_counter_decrease() {
    // deploy the contract
    let (counter, _, _) = __depoly__(ZERO_COUNT);

    assert(counter.get_counter() == 0, 'Counter not decreased');

    counter.decrease_counter();
}

#[test]
fn test_decrease_state_changes() {
    // deploy the contract
    let (counter, _, _) = __depoly__(1);
    let count_1 = counter.get_counter();

    assert(count_1 == 1, 'Counter not set to 1');

    counter.decrease_counter();

    let count_2 = counter.get_counter();

    assert(count_2 == count_1 - 1, 'Counter not decreased');
}

#[test]
fn test_decrease_emitted_events() {
    // deploy the contract
    let (counter, _, _) = __depoly__(1);

    assert(counter.get_counter() == 1, 'Counter not set to 1');
    let mut spy = spy_events();

    // mock a caller
    start_cheat_caller_address(counter.contract_address, USER());
    counter.decrease_counter();
    stop_cheat_caller_address(counter.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Decreased(Counter::Decreased { account: USER() }),
                ),
            ],
        );

    spy
        .assert_not_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Increased(Counter::Increased { account: USER() }),
                ),
            ],
        );
}

#[test]
fn test_decrease_emitted_events_and_state_changes() {
    // deploy the contract
    let (counter, _, _) = __depoly__(1);
    let count_1 = counter.get_counter();

    assert(count_1 == 1, 'Counter not set to 1');
    let mut spy = spy_events();

    // mock a caller
    start_cheat_caller_address(counter.contract_address, USER());
    counter.decrease_counter();
    stop_cheat_caller_address(counter.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Decreased(Counter::Decreased { account: USER() }),
                ),
            ],
        );

    spy
        .assert_not_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Increased(Counter::Increased { account: USER() }),
                ),
            ],
        );

    let count_2 = counter.get_counter();

    assert(count_2 == count_1 - 1, 'Counter not decreased');
}

#[test]
#[fork("SEPOLIA_LATEST")]
fn test_counter_reset_state_changes() {
    // deploy the contract
    let (counter, _, _) = __depoly__(1);

    // mock a caller
    start_cheat_caller_address(counter.contract_address, OWNER());
    // reset the counter
    counter.reset_counter();
    stop_cheat_caller_address(counter.contract_address);

    // count 1
    let count_1 = counter.get_counter();

    assert(count_1 == ZERO_COUNT, 'Counter not reset');
}

#[test]
#[fork("SEPOLIA_LATEST")]
fn test_reset_emitted_events() {
    // deploy the contract
    let (counter, _, _) = __depoly__(1);

    assert(counter.get_counter() == 1, 'Counter not set to 1');
    let mut spy = spy_events();

    // mock a caller
    start_cheat_caller_address(counter.contract_address, OWNER());
    counter.reset_counter();
    stop_cheat_caller_address(counter.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Reset(Counter::Reset { account: OWNER() }),
                ),
            ],
        );
}

#[test]
#[fork("SEPOLIA_LATEST")]
fn test_reset_emitted_events_and_state_changes() {
    // deploy the contract
    let (counter, _, _) = __depoly__(1);
    let count_1 = counter.get_counter();

    assert(count_1 == 1, 'Counter not set to 1');
    let mut spy = spy_events();
    let strk_contract_address: ContractAddress = Counter::FELT_STRK_CONTRACT.try_into().unwrap();
    let strk_dispatcher = IERC20Dispatcher { contract_address: strk_contract_address };
    let contract_balance_before = strk_dispatcher.balance_of(counter.contract_address);
    let caller_balance_before = strk_dispatcher.balance_of(OWNER());

    // mock a caller
    start_cheat_caller_address(counter.contract_address, OWNER());
    counter.reset_counter();

    let contract_balance_after = strk_dispatcher.balance_of(counter.contract_address);
    let caller_balance_after = strk_dispatcher.balance_of(OWNER());

    // contract current balance is 2 * contract previous balance and assert caller sent the STRK
    // token
    assert(contract_balance_after == 2 * contract_balance_before, 'Contract balance not 0');
    assert(
        caller_balance_after == caller_balance_before - contract_balance_before,
        'Caller balance not increased',
    );

    stop_cheat_caller_address(counter.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Reset(Counter::Reset { account: OWNER() }),
                ),
            ],
        );

    let count_2 = counter.get_counter();

    assert(count_2 == ZERO_COUNT, 'Counter not decreased');
}

#[test]
#[fork("SEPOLIA_LATEST")]
fn test_multiple_functions() {
    // deploy the contract
    let (counter, _, _) = __depoly__(10);
    let count_1 = counter.get_counter();

    assert(count_1 == 10, 'Counter not set to 10');
    let mut spy = spy_events();

    // mock a caller
    start_cheat_caller_address(counter.contract_address, USER());

    // increment counter
    counter.increase_counter();

    assert(counter.get_counter() == 11, 'Counter not increased');

    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Increased(Counter::Increased { account: USER() }),
                ),
            ],
        );

    // decrement counter
    counter.decrease_counter();
    assert(counter.get_counter() == 10, 'Counter not decreased');
    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Decreased(Counter::Decreased { account: USER() }),
                ),
            ],
        );

    stop_cheat_caller_address(counter.contract_address);

    start_cheat_caller_address(counter.contract_address, OWNER());
    // reset counter
    counter.reset_counter();
    assert(counter.get_counter() == ZERO_COUNT, 'Counter not reset');
    stop_cheat_caller_address(counter.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Reset(Counter::Reset { account: OWNER() }),
                ),
            ],
        );
}

#[test]
#[fork("SEPOLIA_LATEST")]
fn test_counter_win() {
    // deploy the contract
    let (counter, _, _) = __depoly__(9);
    let count_1 = counter.get_counter();

    assert(count_1 == 9, 'Counter not set to 1');

    let mut spy = spy_events();
    let strk_contract_address: ContractAddress = Counter::FELT_STRK_CONTRACT.try_into().unwrap();
    let strk_dispatcher = IERC20Dispatcher { contract_address: strk_contract_address };
    let contract_balance_before = strk_dispatcher.balance_of(counter.contract_address);
    let caller_balance_before = strk_dispatcher.balance_of(OWNER());

    // mock a caller
    start_cheat_caller_address(counter.contract_address, OWNER());
    counter.increase_counter();

    // assert counter.get_counter() == Counter::WIN_NUMBER, 'Counter not increased to win number');
    assert!(counter.get_counter() == Counter::WIN_NUMBER, "Counter not increased to win number");

    let contract_balance_after = strk_dispatcher.balance_of(counter.contract_address);
    let caller_balance_after = strk_dispatcher.balance_of(OWNER());

    // contract balance is 0 and assert caller received the STRK token
    assert(contract_balance_after == 0, 'Contract balance not 0');
    assert(
        caller_balance_after == caller_balance_before + contract_balance_before,
        'Caller balance not increased',
    );

    stop_cheat_caller_address(counter.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Increased(Counter::Increased { account: OWNER() }),
                ),
            ],
        );

    assert(counter.get_counter() == Counter::WIN_NUMBER, 'Counter not increased');
}
