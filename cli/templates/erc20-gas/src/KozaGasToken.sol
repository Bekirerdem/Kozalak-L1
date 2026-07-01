// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title KozaGasToken
 * @author kozalak-L1 contributors
 * @notice ERC-20 + Capped + Permit + Ownable2Step token. Subnet-EVM L1'de native gas
 *         token olarak veya C-Chain üzerinde yardımcı token olarak kullanılabilir.
 * @dev OpenZeppelin v5.3+ pattern'leri ile audit-grade boilerplate. Custom logic minimum.
 *
 *      Güvenlik:
 *      - Ownable2Step: tek-adımlı ownership transfer riski sıfırlanır (yanlış adres koruması)
 *      - ERC20Capped: total supply hard-cap, sınırsız enflasyon yok
 *      - ERC20Permit (EIP-2612): gasless approve, smart wallet UX
 *      - Custom errors: gas + audit kalitesi (require string yerine)
 *
 *      Constructor input validation OpenZeppelin parent kontratlarına bırakıldı:
 *      - cap_ == 0       → ERC20Capped.ERC20InvalidCap(0)
 *      - initialOwner_ 0 → Ownable.OwnableInvalidOwner(0)
 *      Bu sayede çift kontrol (gas waste) ve hata mesajı çakışması olmaz.
 */
contract KozaGasToken is ERC20Capped, ERC20Permit, Ownable2Step {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sıfır miktar parametresi geçerli değil (mint, burn için).
    error ZeroAmount();

    /// @notice Constructor'daki ilk mint cap'i aşıyor.
    /// @param cap Maksimum total supply
    /// @param attempted İstenen ilk mint miktarı
    error InitialMintExceedsCap(uint256 cap, uint256 attempted);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param name_ Token adı (örn. "Koza Gas Token")
     * @param symbol_ Token sembolü (örn. "KGAS")
     * @param cap_ Maksimum total supply (wei cinsinden, decimal'i içerir)
     * @param initialMint_ Constructor'da `initialOwner_`'a mint edilecek miktar (0 olabilir)
     * @param initialOwner_ Owner adresi (production: multisig, asla EOA değil)
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 cap_,
        uint256 initialMint_,
        address initialOwner_
    )
        ERC20(name_, symbol_)
        ERC20Capped(cap_)
        ERC20Permit(name_)
        Ownable(initialOwner_)
    {
        if (initialMint_ > cap_) {
            revert InitialMintExceedsCap(cap_, initialMint_);
        }

        if (initialMint_ > 0) {
            _mint(initialOwner_, initialMint_);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Yeni token mint et. Sadece owner çağırabilir.
     * @dev Cap kontrolü ERC20Capped tarafından `_update` içinde otomatik yapılır.
     *      Sıfır adres kontrolü ERC20 `_mint` içinde yapılır (ERC20InvalidReceiver).
     * @param to Mint edilecek adres
     * @param amount Mint miktarı (wei cinsinden)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroAmount();
        _mint(to, amount);
    }

    /**
     * @notice Çağıran kişi kendi token'larını yakar.
     * @param amount Yakılacak miktar (wei cinsinden)
     */
    function burn(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        _burn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                              OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @dev ERC20 ve ERC20Capped'in `_update` fonksiyonları çakışıyor; üst sınıfa delegate et.
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Capped) {
        super._update(from, to, value);
    }
}
