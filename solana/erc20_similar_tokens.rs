use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer};

declare_id!("YourProgramIDHere");

#[program]
pub mod erc20_multistaking {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>, lock_period: i64) -> Result<()> {
        let config = &mut ctx.accounts.config;
        config.lock_period = lock_period;
        config.total_staked = 0;
        Ok(())
    }

    pub fn stake(ctx: Context<Stake>, amount: u64, to_pool: String) -> Result<()> {
        let staker = &mut ctx.accounts.staker;
        let pool = &mut ctx.accounts.pool;

        require!(amount > 0, ErrorCode::InvalidAmount);

        // Transfer tokens from staker to pool
        let cpi_accounts = Transfer {
            from: ctx.accounts.staker_token_account.to_account_info(),
            to: ctx.accounts.pool_token_account.to_account_info(),
            authority: ctx.accounts.staker.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
        token::transfer(cpi_ctx, amount)?;

        // Update pool and staker balances
        pool.total_staked += amount;
        staker.balance += amount;

        emit!(StakeOccurred {
            staker: *staker.to_account_info().key,
            pool: *pool.to_account_info().key,
            amount,
            to_pool,
        });

        Ok(())
    }

    pub fn unstake(ctx: Context<Unstake>, amount: u64, from_pool: String) -> Result<()> {
        let staker = &mut ctx.accounts.staker;
        let pool = &mut ctx.accounts.pool;

        require!(amount > 0, ErrorCode::InvalidAmount);
        require!(staker.balance >= amount, ErrorCode::InsufficientFunds);

        staker.balance -= amount;
        pool.total_staked -= amount;

        staker.withdrawal_requests.push(WithdrawalRequest {
            amount,
            unlock_time: Clock::get()?.unix_timestamp + ctx.accounts.config.lock_period,
        });

        emit!(UnstakeRequested {
            staker: *staker.to_account_info().key,
            pool: *pool.to_account_info().key,
            amount,
            unlock_time: Clock::get()?.unix_timestamp + ctx.accounts.config.lock_period,
            from_pool,
        });

        Ok(())
    }

    pub fn withdraw(ctx: Context<Withdraw>) -> Result<()> {
        let staker = &mut ctx.accounts.staker;
        let pool = &mut ctx.accounts.pool;
        let current_time = Clock::get()?.unix_timestamp;

        let mut total_withdrawable = 0;

        staker.withdrawal_requests.retain(|request| {
            if request.unlock_time <= current_time {
                total_withdrawable += request.amount;
                false // Remove processed requests
            } else {
                true // Retain pending requests
            }
        });

        require!(total_withdrawable > 0, ErrorCode::NoWithdrawableFunds);

        // Transfer tokens from pool to staker
        let cpi_accounts = Transfer {
            from: ctx.accounts.pool_token_account.to_account_info(),
            to: ctx.accounts.staker_token_account.to_account_info(),
            authority: ctx.accounts.pool.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
        token::transfer(cpi_ctx, total_withdrawable)?;

        emit!(WithdrawalOccurred {
            staker: *staker.to_account_info().key,
            amount: total_withdrawable,
        });

        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(init, payer = user, space = 8 + 8 + 8)]
    pub config: Account<'info, Config>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Stake<'info> {
    #[account(mut)]
    pub staker: Signer<'info>,
    #[account(mut)]
    pub staker_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub pool: Account<'info, Pool>,
    #[account(mut)]
    pub pool_token_account: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct Unstake<'info> {
    #[account(mut)]
    pub staker: Signer<'info>,
    #[account(mut)]
    pub staker_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub pool: Account<'info, Pool>,
    #[account(mut)]
    pub config: Account<'info, Config>,
    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct Withdraw<'info> {
    #[account(mut)]
    pub staker: Signer<'info>,
    #[account(mut)]
    pub staker_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub pool: Account<'info, Pool>,
    #[account(mut)]
    pub pool_token_account: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
}

#[account]
pub struct Config {
    pub lock_period: i64,
    pub total_staked: u64,
}

#[account]
pub struct Staker {
    pub balance: u64,
    pub withdrawal_requests: Vec<WithdrawalRequest>,
}

#[account]
pub struct Pool {
    pub total_staked: u64,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct WithdrawalRequest {
    pub amount: u64,
    pub unlock_time: i64,
}

#[event]
pub struct StakeOccurred {
    pub staker: Pubkey,
    pub pool: Pubkey,
    pub amount: u64,
    pub to_pool: String,
}

#[event]
pub struct UnstakeRequested {
    pub staker: Pubkey,
    pub pool: Pubkey,
    pub amount: u64,
    pub unlock_time: i64,
    pub from_pool: String,
}

#[event]
pub struct WithdrawalOccurred {
    pub staker: Pubkey,
    pub amount: u64,
}

#[error_code]
pub enum ErrorCode {
    #[msg("Invalid amount")]
    InvalidAmount,
    #[msg("Insufficient funds")]
    InsufficientFunds,
    #[msg("No withdrawable funds")]
    NoWithdrawableFunds,
}
