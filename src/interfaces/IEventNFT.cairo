use starknet::ContractAddress;

/// @title Event NFT Interface
/// @notice Interface for minting and burning event-specific NFTs
/// @dev Implements basic NFT functionality for event attendance tracking
#[starknet::interface]
pub trait IEventNFT<TContractState> {
    fn mint_nft(ref self: TContractState, user_address: ContractAddress) -> u256;
    fn burn_nft(ref self: TContractState, user_address: ContractAddress, token_id: u256);
}
