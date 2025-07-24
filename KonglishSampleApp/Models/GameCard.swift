import Foundation

/// 카드에 들어가는 데이터를 표현하는 구조체
struct GameCard: Hashable {
    /// 카드의 아이디
    let id: UUID
    
    /// 이미지 이름
    let imageName: String?
    
    /// 한국어 뜻
    let wordKor: String
    
    /// 영어 철자
    let wordEng: String
    
    init(id: UUID = UUID(), imageName: String? = nil, wordKor: String, wordEng: String) {
        self.id = id
        self.imageName = imageName
        self.wordKor = wordKor
        self.wordEng = wordEng
    }
}