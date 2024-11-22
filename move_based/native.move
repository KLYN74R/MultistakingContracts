module Stake::NativeStaking {

    struct Config has store {
        lock_period: u64,
        total_staked: u64,
    }

    struct StakePool has store {
        staked_amount: u64,
    }

    struct WithdrawalRequest has store {
        amount: u64,
        unlock_time: u64,
    }

    struct UserAccount has store {
        staked_balance: u64,
        withdrawal_requests: vector<WithdrawalRequest>,
    }

    public fun initialize(
        admin: &signer,
        lock_period: u64
    ): Config {
        Config { lock_period, total_staked: 0 }
    }

    public fun stake(
        user: &signer,
        pool: &mut StakePool,
        amount: u64,
        config: &mut Config
    ) {
        assert!(amount > 0, 1);
        pool.staked_amount = pool.staked_amount + amount;
        config.total_staked = config.total_staked + amount;

        // Deduct native tokens from user's balance
        move_to<StakePool>(user, pool);
    }

    public fun unstake(
        user: &signer,
        pool: &mut StakePool,
        amount: u64,
        config: &mut Config,
        user_account: &mut UserAccount
    ) {
        assert!(amount > 0, 1);
        assert!(pool.staked_amount >= amount, 2);

        pool.staked_amount = pool.staked_amount - amount;
        user_account.staked_balance = user_account.staked_balance - amount;

        let current_time = Timestamp::now();
        let unlock_time = current_time + config.lock_period;

        let request = WithdrawalRequest {
            amount,
            unlock_time,
        };

        vector::push_back(&mut user_account.withdrawal_requests, request);
    }

    public fun withdraw(
        user: &signer,
        user_account: &mut UserAccount
    ) {
        let current_time = Timestamp::now();
        let mut total_withdrawable = 0;

        vector::retain(
            &mut user_account.withdrawal_requests,
            |req| {
                if (req.unlock_time <= current_time) {
                    total_withdrawable = total_withdrawable + req.amount;
                    false
                } else {
                    true
                }
            },
        );

        assert!(total_withdrawable > 0, 3);

        // Transfer tokens back to user
        Coin::transfer(user, total_withdrawable);
    }
}
