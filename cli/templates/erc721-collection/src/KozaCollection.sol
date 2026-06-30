// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title KozaCollection
 * @author kozalak-L1 contributors
 * @notice ERC-721 + ERC-2981 royalty + Ownable2Step + Merkle allowlist NFT koleksiyonu.
 *         Avalanche L1 veya C-Chain üzerinde audit-grade boilerplate.
 * @dev OpenZeppelin v5.3+ pattern'leri. Token id'ler 1'den başlar (UX/explorer kolaylığı).
 *
 *      Faz akışı:
 *        Closed     → mint kapalı, sadece deploy sonrası başlangıç
 *        Allowlist  → sadece Merkle proof'u doğrulanan adresler (tek seferlik claim)
 *        Public     → herkese açık
 *
 *      Güvenlik kararları:
 *      - Ownable2Step: yanlış adrese ownership transferi engellenir
 *      - immutable maxSupply: deploy sonrası kapasite değiştirilemez
 *      - Strict msg.value: fazla ödeme refund edilmez (basit, deterministik). Frontend
 *        kullanıcıya net miktarı göstermek zorunda
 *      - Merkle leaf = keccak256(abi.encodePacked(address)) — basit, sadece "kim"i
 *        kanıtlar; quota MAX_PER_WALLET ile sınırlandırılır
 *      - Per-wallet mint cap (her fazı kapsar) Sybil saldırılarını yavaşlatır ama
 *        çoklu cüzdan tamamen engellenmez (KYC seviyesinde değil)
 *      - withdraw `call`'i target'a istediği gibi davranma yetkisi verir; reentrancy
 *        riski yok çünkü mint/setter fonksiyonlarda durum güncellemeleri tüm external
 *        çağrılardan ÖNCE yapılır (CEI pattern)
 *      - ERC-2981 royalty marketplace'in saygı göstermesine bağlıdır (OpenSea Operator
 *        Filter, Joepegs vb. — protokol seviyesinde garantisi yoktur)
 */
contract KozaCollection is ERC721, ERC2981, Ownable2Step {
    using Strings for uint256;

    /*//////////////////////////////////////////////////////////////
                                  TYPES
    //////////////////////////////////////////////////////////////*/

    enum Phase {
        Closed,
        Allowlist,
        Public
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Tek bir cüzdanın tüm fazlar boyunca toplam mint edebileceği üst sınır.
    uint256 public constant MAX_PER_WALLET = 10;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Toplam basılabilir token sayısı (deploy'da sabit, immutable).
    uint256 public immutable maxSupply;

    /// @notice Şimdiye kadar basılan toplam token sayısı (id artışı için kullanılır,
    ///         burn olsa bile geri sayılmaz).
    uint256 public totalMinted;

    /// @notice Mint başına ödenecek native gas miktarı (wei).
    uint256 public mintPrice;

    /// @notice Allowlist Merkle ağacının kök hash'i.
    bytes32 public merkleRoot;

    /// @notice Aktif mint fazı.
    Phase public phase;

    /// @dev `tokenURI` için `_baseURI()` override sonucu.
    string private _baseTokenURI;

    /// @notice Cüzdan başına şimdiye kadarki mint sayısı (allowlist + public toplam).
    mapping(address account => uint256 minted) public mintedPerWallet;

    /// @notice Allowlist'i bir kez kullanan adresler (yeniden claim engeli).
    mapping(address account => bool claimed) public allowlistClaimed;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PhaseChanged(Phase indexed newPhase);
    event MerkleRootSet(bytes32 indexed newRoot);
    event BaseURISet(string newBaseURI);
    event MintPriceSet(uint256 newPrice);
    event Withdrawn(address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error MaxSupplyZero();
    error MaxSupplyReached(uint256 supplyCap, uint256 attempted);
    error InvalidProof();
    error AlreadyClaimed(address account);
    error IncorrectPayment(uint256 sent, uint256 required);
    error WithdrawFailed();
    error WrongPhase(Phase current, Phase required);
    error ZeroQuantity();
    error ExceedsPerWalletLimit(uint256 current, uint256 attempted, uint256 max);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param name_ Koleksiyon adı (örn. "Koza Genesis")
     * @param symbol_ Koleksiyon sembolü (örn. "KOZA")
     * @param baseURI_ Metadata IPFS/HTTPS prefix (sonu `/` ile bitmeli, tokenURI = baseURI + id)
     * @param maxSupply_ Toplam basılabilir token sayısı (immutable)
     * @param mintPrice_ Token başına native gas ücreti (wei, 0 olabilir)
     * @param royaltyReceiver_ Default ERC-2981 royalty alıcısı (multisig önerilir)
     * @param royaltyBps_ Royalty oranı BPS cinsinden (1000 = %10, max 10000 = %100)
     * @param initialOwner_ Owner adresi (production: multisig, asla EOA değil)
     */
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint256 maxSupply_,
        uint256 mintPrice_,
        address royaltyReceiver_,
        uint96 royaltyBps_,
        address initialOwner_
    )
        ERC721(name_, symbol_)
        Ownable(initialOwner_)
    {
        if (maxSupply_ == 0) revert MaxSupplyZero();

        maxSupply = maxSupply_;
        mintPrice = mintPrice_;
        _baseTokenURI = baseURI_;

        // OZ ERC2981 royaltyBps_ <= _feeDenominator() (10000) kontrolünü kendi içinde yapar
        // ve receiver_ != address(0) kontrolü uygular. Ek revert tanımına gerek yok.
        _setDefaultRoyalty(royaltyReceiver_, royaltyBps_);
    }

    /*//////////////////////////////////////////////////////////////
                                MINTING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allowlist fazında, Merkle proof ile mint et.
     * @dev Tek seferlik claim. Aynı adres ikinci kez allowlistMint çağıramaz; ama public
     *      faza geçtiğinde publicMint yapabilir (MAX_PER_WALLET izin verdiği kadar).
     * @param quantity Bu çağrıda mint edilecek miktar
     * @param proof Çağıranın Merkle ağacındaki yaprak kanıtı
     */
    function allowlistMint(uint256 quantity, bytes32[] calldata proof) external payable {
        if (phase != Phase.Allowlist) revert WrongPhase(phase, Phase.Allowlist);
        if (allowlistClaimed[msg.sender]) revert AlreadyClaimed(msg.sender);

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (!MerkleProof.verifyCalldata(proof, merkleRoot, leaf)) revert InvalidProof();

        // CEI: önce state, sonra ödeme + mint
        allowlistClaimed[msg.sender] = true;
        _mintBatch(msg.sender, quantity);
    }

    /**
     * @notice Public faz mint. Herkese açık.
     * @param quantity Bu çağrıda mint edilecek miktar
     */
    function publicMint(uint256 quantity) external payable {
        if (phase != Phase.Public) revert WrongPhase(phase, Phase.Public);
        _mintBatch(msg.sender, quantity);
    }

    /*//////////////////////////////////////////////////////////////
                              OWNER ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Allowlist Merkle ağacının yeni kökünü ata.
    function setMerkleRoot(bytes32 newRoot) external onlyOwner {
        merkleRoot = newRoot;
        emit MerkleRootSet(newRoot);
    }

    /// @notice Aktif mint fazını değiştir.
    function setPhase(Phase newPhase) external onlyOwner {
        phase = newPhase;
        emit PhaseChanged(newPhase);
    }

    /// @notice tokenURI prefix'ini güncelle (örn. reveal sonrası).
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURISet(newBaseURI);
    }

    /// @notice Token başına mint ücretini güncelle.
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceSet(newPrice);
    }

    /// @notice Default ERC-2981 royalty bilgisini güncelle.
    /// @dev Tüm token'lar için varsayılan; per-token override yok (bu template'te).
    function setDefaultRoyalty(address receiver, uint96 bps) external onlyOwner {
        _setDefaultRoyalty(receiver, bps);
    }

    /**
     * @notice Kontratta biriken native gas'ı hedef adrese çek.
     * @dev `to` çağrı sırasında reentrancy yapamaz çünkü withdraw'da güncellenecek
     *      durum yok (balance native zaten transfer edilirken sıfırlanır). Yine de
     *      Withdrawn event'i call'dan önce emit edilir; başarısızsa revert tüm
     *      durumu geri alır.
     */
    function withdraw(address payable to) external onlyOwner {
        uint256 balance = address(this).balance;
        emit Withdrawn(to, balance);
        (bool success,) = to.call{value: balance}("");
        if (!success) revert WithdrawFailed();
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ERC721
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /// @notice Birden fazla interface (ERC721, ERC2981) desteklendiği için override.
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Mint helper'ı. Quantity, supply, per-wallet ve ödeme kontrollerini yapar,
     *      `_safeMint` ile id'leri sırayla basar.
     *
     *      Strict `msg.value == required` kullanıyoruz — fazla ödeme refund edilmez.
     *      Bu basitlik audit yüzeyini küçültür ve frontend'in net hesap göstermesini
     *      zorunlu kılar. İhtiyaç durumunda fork'ta `>=` + refund eklenebilir.
     */
    function _mintBatch(address to, uint256 quantity) private {
        if (quantity == 0) revert ZeroQuantity();

        uint256 currentMinted = mintedPerWallet[to];
        if (currentMinted + quantity > MAX_PER_WALLET) {
            revert ExceedsPerWalletLimit(currentMinted, quantity, MAX_PER_WALLET);
        }

        uint256 totalAfter = totalMinted + quantity;
        if (totalAfter > maxSupply) revert MaxSupplyReached(maxSupply, totalAfter);

        uint256 required = mintPrice * quantity;
        if (msg.value != required) revert IncorrectPayment(msg.value, required);

        // CEI: state güncellemeleri _safeMint'ten ÖNCE yapılır (reentrancy guard)
        mintedPerWallet[to] = currentMinted + quantity;
        uint256 startId = totalMinted;
        totalMinted = totalAfter;

        for (uint256 i = 0; i < quantity;) {
            // Token id 1'den başlasın (UX için)
            _safeMint(to, startId + i + 1);
            unchecked {
                ++i;
            }
        }
    }
}
