// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title KozaCredential
 * @author kozalak-L1 contributors
 * @notice Account-bound (soulbound) sertifika NFT — transfer edilemez, issuer-only mint,
 *         on-chain metadata, revoke-flag. Avalanche L1 / C-Chain için audit-grade boilerplate.
 * @dev OpenZeppelin v5.3+ pattern'leri. Token id'ler 1'den başlar (UX/explorer kolaylığı).
 *      Use-case: eğitim/topluluk platformlarının (örn. ARIA Hub) mezun/üye sertifikası.
 *
 *      Neden ERC-5114 değil: ERC-5114 rozeti bir NFT'ye kalıcı bağlar (cüzdana değil) ve
 *      revoke/transfer/burn'e izin vermez. Eğitim sertifikası "kişiye verilir + issuer
 *      revoke edebilmeli" gereksinimine account-bound ERC-721 + revoke-flag oturur.
 *
 *      Güvenlik kararları:
 *      - Soulbound: `_update` override ile transfer (from≠0 && to≠0) revert eder. Sadece
 *        mint izinli; `approve`/`setApprovalForAll` çağrılabilir ama transfer yine bloklu,
 *        dolayısıyla fiilen etkisizdir. Token cüzdana kilitlidir.
 *      - Revoke-flag (burn değil): iptal edilen sertifika silinmez, `revoked=true`
 *        işaretlenir; `ownerOf` çözülmeye devam eder. "Sertifika vardı, iptal edildi"
 *        on-chain denetlenebilir kalır. `isValid` ve metadata `Status`'a yansır.
 *      - AccessControl: ISSUER_ROLE (issue + revoke) ile DEFAULT_ADMIN_ROLE (rol yönetimi)
 *        ayrıdır. Production: admin = Safe (Gnosis) multisig, asla EOA değil. Çoklu
 *        eğitmen/issuer admin tarafından `grantRole(ISSUER_ROLE, ...)` ile eklenir.
 *      - On-chain metadata: kurs/issuer/tarih/durum zincirde saklanır, `tokenURI` base64
 *        JSON üretir. IPFS/sunucu ölse bile sertifikanın kanıt değeri kaybolmaz.
 *      - Minimum custom logic: audited OZ ERC721 + AccessControl primitive'leri üstüne
 *        ince katman. CEI: `issue` state'i `_safeMint`'ten ÖNCE yazar.
 *      - `course` metni JSON'a düz gömülür; issuer güvenilir aktördür (rol-korumalı).
 *        Untrusted girdi senaryosunda `"` escape'i gerekir — bu template issuer-trusted varsayar.
 */
contract KozaCredential is ERC721, AccessControl {
    using Strings for uint256;

    /*//////////////////////////////////////////////////////////////
                                  TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Tek bir sertifikanın on-chain kaydı.
    struct Credential {
        string course; // sertifikanın konusu (kurs/etkinlik adı)
        address issuer; // mint anında ISSUER_ROLE sahibi çağıran
        uint64 issuedAt; // mint block.timestamp
        bool revoked; // issuer tarafından iptal edildi mi
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sertifika mint + revoke yetkisi olan rol.
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Şimdiye kadar verilen toplam sertifika (id artışı için; id'ler 1'den başlar).
    uint256 public totalIssued;

    /// @dev tokenId → on-chain credential kaydı. Dış erişim `getCredential` ile.
    mapping(uint256 tokenId => Credential) private _credentials;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CredentialIssued(uint256 indexed tokenId, address indexed to, address indexed issuer, string course);
    event CredentialRevoked(uint256 indexed tokenId, address indexed issuer);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sertifika transfer edilemez (account-bound).
    error Soulbound();
    /// @notice `course` boş olamaz.
    error EmptyCourse();
    /// @notice Sertifika zaten iptal edilmiş.
    error AlreadyRevoked(uint256 tokenId);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param name_ Sertifika koleksiyonu adı (örn. "ARIA Hub Credential")
     * @param symbol_ Sembol (örn. "ARIA")
     * @param admin DEFAULT_ADMIN_ROLE sahibi — rol yönetimi (production: multisig)
     * @param issuer_ İlk ISSUER_ROLE sahibi — sertifika verir/iptal eder
     */
    constructor(string memory name_, string memory symbol_, address admin, address issuer_) ERC721(name_, symbol_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ISSUER_ROLE, issuer_);
    }

    /*//////////////////////////////////////////////////////////////
                              ISSUER ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Bir adrese soulbound sertifika ver.
     * @param to Sertifikayı alacak cüzdan
     * @param course Sertifikanın konusu (boş olamaz)
     * @return tokenId Verilen sertifikanın id'si (1'den başlar)
     */
    function issue(address to, string calldata course) external onlyRole(ISSUER_ROLE) returns (uint256 tokenId) {
        if (bytes(course).length == 0) revert EmptyCourse();

        // CEI: state güncellemeleri _safeMint'ten (external call) ÖNCE yapılır.
        tokenId = ++totalIssued;
        _credentials[tokenId] =
            Credential({course: course, issuer: msg.sender, issuedAt: uint64(block.timestamp), revoked: false});

        emit CredentialIssued(tokenId, to, msg.sender, course);
        _safeMint(to, tokenId);
    }

    /**
     * @notice Verilmiş bir sertifikayı iptal et (token silinmez, `revoked` işaretlenir).
     * @param tokenId İptal edilecek sertifika
     */
    function revoke(uint256 tokenId) external onlyRole(ISSUER_ROLE) {
        _requireOwned(tokenId); // yoksa ERC721NonexistentToken
        if (_credentials[tokenId].revoked) revert AlreadyRevoked(tokenId);

        _credentials[tokenId].revoked = true;
        emit CredentialRevoked(tokenId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sertifika geçerli mi (mevcut ve iptal edilmemiş).
    function isValid(uint256 tokenId) external view returns (bool) {
        return _ownerOf(tokenId) != address(0) && !_credentials[tokenId].revoked;
    }

    /// @notice Sertifikanın on-chain kaydını döndür.
    function getCredential(uint256 tokenId) external view returns (Credential memory) {
        return _credentials[tokenId];
    }

    /**
     * @notice On-chain üretilen base64 JSON metadata (IPFS bağımsız).
     * @dev Token yoksa ERC721NonexistentToken revert eder (`_requireOwned`).
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        Credential storage c = _credentials[tokenId];

        string memory json = string.concat(
            '{"name":"',
            name(),
            " #",
            tokenId.toString(),
            '","description":"Soulbound, transfer edilemez on-chain sertifika (Kozalak-L1 Template 4).",',
            '"attributes":[',
            '{"trait_type":"Course","value":"',
            c.course,
            '"},',
            '{"trait_type":"Issuer","value":"',
            Strings.toHexString(c.issuer),
            '"},',
            '{"trait_type":"Issued","display_type":"date","value":',
            uint256(c.issuedAt).toString(),
            "},",
            '{"trait_type":"Status","value":"',
            c.revoked ? "Revoked" : "Valid",
            '"}]}'
        );

        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Soulbound kilidi: transfer (from≠0 && to≠0) yasak. Mint (from=0) izinli.
     *      Burn bu template'te kullanılmaz (revoke flag tercih edildi).
     */
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) revert Soulbound();
        return super._update(to, tokenId, auth);
    }

    /// @notice Birden fazla interface (ERC721, AccessControl) desteklendiği için override.
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
