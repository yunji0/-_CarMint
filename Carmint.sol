// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
//pragma solidity >=0.7.0 <0.9.0;
//pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TeamNFT is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;


    ///////////////////////////////상태변수////////////////////////////////
    uint256 public totalSupply;
    address payable public mainOwner;
    struct tokenInfo{
        uint256 tokenPrice;
        address tokenOwner;
        bool isSell;
        bool isApproval;
        bool isApproval_user;
        bool isApproval_insurance;
        bool isExpired;
        uint8 modeCount; // 0: 시승중 1: 계약연장 2: 구매확정 3. 반납 4. 사고발생
        uint8 accident_cnt;
        uint8 tuning_cnt;
        uint256 Timelog;
        uint8 driveDue; //시승 기간 CNt
 
    }

    struct addressInfo{
        uint256 balances;
        bool isBlacklist;
    }

    // meta json =>

    mapping(address => addressInfo) public addressParser;
    mapping(uint256 => tokenInfo) public tokenParser;
  //  addressInfo[] public addressParser;
    //tokenInfo[] public tokenParser;

    //////////////////////////////////////////////////////////////////////
    constructor() ERC721("Test", "TS") { 
        mainOwner = payable(msg.sender);
        totalSupply =0;
        }


    function _baseURI() internal pure override returns (string memory) {
        return "https://ipfs.infura.io:5001/api/v0/cat?arg=";




    }
////////////////////////////////모든 노드 공용 함수/////////////////////////////////////
    function showTokenInfo(uint256 targetTokenID) public view returns(tokenInfo memory){
        return tokenParser[targetTokenID];
    } //토큰 정보 보여주는 함수\
    function showUserInfo(address targetUseraddress) public view returns(addressInfo memory){
        return addressParser[targetUseraddress];
    } //유저 정보 보여주는 함수




///////////////////////////////////////판매자용 함수//////////////////////////////////////
    function CarMint(address to, string memory uri, uint256 uploadTokenPrice) public payable onlyOwner {
        uint256 tokenId = _tokenIdCounter.current(); 
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        tokenParser[tokenId].tokenPrice = uploadTokenPrice;
        tokenParser[tokenId].tokenOwner = to;
        tokenParser[tokenId].isSell = false;
        tokenParser[tokenId].isApproval_user =true;
        tokenParser[tokenId].isApproval=false;
        tokenParser[tokenId].isExpired =false;
        tokenParser[tokenId].modeCount= 127;
        tokenParser[tokenId].accident_cnt=0;
        tokenParser[tokenId].tuning_cnt = 0;
        tokenParser[tokenId].driveDue = 0;
        addressParser[to].balances= addressParser[to].balances+1;

        
                //tokenParser.push(tokenInfo(uploadTokenPrice, to, false,false,true,false,false,127,0,0,0,0));

        mainOwner.transfer(msg.value); // 수수료 상납
        totalSupply = totalSupply+1;
        
    }//토큰 생성 함수


function Selling(uint256 _tokenId)public{   //판다고 요청
    
    require(tokenParser[_tokenId].isApproval== true,"Hash Error");
  
    tokenParser[_tokenId].isSell =  true;
}


///////////////////보험사용 함수/////////////////
function Submit(uint256 _tokenId)public{  //서류 제출 및 검토 완료
    tokenParser[_tokenId].isApproval_insurance =  true;
    require(tokenParser[_tokenId].isApproval_user== true,"User don't submit");
    tokenParser[_tokenId].isApproval= true;
   
    
}


///////////////////구매자용 함수//////////////////////////////////////////////////////
    function CarTransfer(address payable _Seller, address payable Consumer, uint256 _tokenId, uint8 _modeCount) public payable {
       //modChanger랑 거래 함수 합쳐버림
        require(tokenParser[_tokenId].isSell == true,"is not sell");
        require(tokenParser[_tokenId].isApproval == true,"is not Approval");
        //require(tokenParser[_tokenId].tokenOwner == msg.sender,"is not Owner");
        if((tokenParser[_tokenId].modeCount == 127) &&(_modeCount == 0)){ //최초 구매(강제 시승 1달)
        tokenParser[_tokenId].modeCount = 0;
        tokenParser[_tokenId].Timelog = block.timestamp;
        tokenParser[_tokenId].tokenOwner = mainOwner; //잠깐 우리가 가져갑니다~
        tokenParser[_tokenId].driveDue = tokenParser[_tokenId].driveDue+1;
        mainOwner.transfer(msg.value); //우리에게 수수료+ 차 전체 가격 상납
        }else if ((_modeCount ==1)&& (block.timestamp >=tokenParser[_tokenId].Timelog +30 days )){ //시승 연장
             tokenParser[_tokenId].driveDue = tokenParser[_tokenId].driveDue+1;
             tokenParser[_tokenId].Timelog = block.timestamp;
             mainOwner.transfer(msg.value); //우리에게 수수료 상납, 시승 기간 연장
        } else if(_modeCount ==2 && (block.timestamp >=tokenParser[_tokenId].Timelog +30 days )){
             require(msg.sender == mainOwner,"Changing Node is Dapp's role");
            _Seller.transfer(msg.value); //구매 확정, 이건 mainOwner노드에서 써야함 
             tokenParser[_tokenId].driveDue = 0;
             tokenParser[_tokenId].tokenOwner =Consumer;
             tokenParser[_tokenId].modeCount = 127;
           

        }else if(_modeCount ==3&& (block.timestamp >=tokenParser[_tokenId].Timelog +30 days )){//반납, 이건 mainOwner노드에서 써야함 
             require(msg.sender == mainOwner,"Changing Node is Dapp's role");
             tokenParser[_tokenId].driveDue = 0;
             tokenParser[_tokenId].tokenOwner =_Seller;
             tokenParser[_tokenId].modeCount = 127;
             Consumer.transfer(msg.value); //  처음 입금 받음 금액 -[tokenParser[_tokenId].driveDue * (1달 이용료) +수수료]를 다시 캐시백


        }
    
    } //super.safeTransferFrom(from, to, tokenId);
/////////////////////////차량 노드//////////////////////////////////////
function Accident(address payable _Seller, uint256 _tokenId)public payable{  //사고 발생
    tokenParser[_tokenId].accident_cnt =  tokenParser[_tokenId].accident_cnt +1;
     tokenParser[_tokenId].isApproval = false;
     tokenParser[_tokenId].isApproval_insurance = false;
     tokenParser[_tokenId].isApproval_user = false;

    tokenParser[_tokenId].tokenOwner = _Seller;
    _Seller.transfer(msg.value);
}





   
    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

     function close() public{
         if(msg.sender != mainOwner) revert();
         selfdestruct(mainOwner);

     }


}
