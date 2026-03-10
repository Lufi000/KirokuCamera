# 欧盟《数字服务法》(DSA) 合规指南

根据 DSA 第 30、31 条，在欧盟地区分发 App 的**交易商**必须在 App Store Connect 中申报并验证联系信息，Apple 会将该信息展示在 App 的欧盟产品页上。即使你不向欧盟分发，也需**声明是否为交易商**。

---

## 1. 你是否为「交易商」？

DSA 定义：**为与自己的贸易、经营、手艺或职业相关之目的而行为的自然人或法人**。

自评时可参考（非穷尽）：

| 因素 | 更可能为交易商 | 更可能非交易商 |
|------|----------------|----------------|
| 收入 | 有 IAP、付费 App、广告等收入 | 无收入或纯爱好 |
| 商业行为 | 有广告、推广、营销 | 无商业推广 |
| 税务 | 已做增值税 (VAT) 登记 | 无 |
| 身份 | 以公司/职业身份开发 | 个人爱好、非商业 |

**不确定时请咨询法律顾问。** 若仅个人爱好、无商业化意图，通常可申报「非交易商」。

---

## 2. 在 App Store Connect 中完成申报

**入口**：App Store Connect 首页 → **Business（业务）** → **Agreements（协议）** → 向下滚动到 **Compliance（合规）** → **Digital Services Act** → **Complete Compliance Requirements（完成合规要求）**。

### 若选择「This is not a trader account」（非交易商）

- 选择后点击 **Done** 即可，无需填写联系信息。
- 欧盟用户会被告知：与你的合同不适用基于消费者保护法的消费者权利。

### 若选择「This is a trader account」（交易商）

需提供并验证以下信息（将显示在欧盟 App 产品页）：

- **个人开发者**：地址或邮政信箱、电话、邮箱  
- **组织开发者**：地址以 D-U-N-S 为准自动显示，需再填写：电话、邮箱  

步骤概要：

1. 填写上述联系信息 → **Next**。
2. 用**两步验证**验证所填邮箱。
3. 用**两步验证**验证所填电话（无法收验证码可申请人工验证）。
4. 上传**证明文件**：能证明企业/主体名称与地址的当前文件（如营业执照、法律文书）。若使用备用地址（如 P.O. Box），须另附证明你与该地址关联的文件（如账单、收据）。
5. 确认信息无误 → **Confirm**。

此外需确保已在 App Store Connect 中填写**付款账户**，并确认所提供之产品/服务符合欧盟适用法律。

---

## 3. 按 App 单独设置（可选）

若整体申报为交易商，仍可为某个 App 关闭「交易商」展示：

**Apps** → 选择对应 App → **App Information** → **App Store Regulations and Permits** → **Digital Services Act** → **Edit**，在该弹窗中修改该 App 的交易商状态。

---

## 4. 标签与标识 URL（可选）

若欧盟法要求你的 App 展示特定标签或标识，可提供 **Labels and Markings URL**：

**Apps** → 选择 App → **App Information** → **App Store Regulations and Permits** → **Add Labels and Markings**，填写 URL。仅在你已标识为交易商的 App 上会显示。

---

## 5. 与本项目现有信息的对应

- **邮箱**：你已在 `docs/support.html` 与 `docs/privacy-policy.html` 中使用 `loyatfei@gmail.com`，若申报为交易商，可在 DSA 信息中填写同一邮箱（须能接收 Apple 的验证码）。
- **电话与地址**：若选交易商，须在 App Store Connect 中单独填写并验证，与网页上的联系方式可一致，但以 Connect 中验证通过的为准。

---

## 6. 参考链接

- [Apple 官方：Manage EU DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- [DSA trader status 要求（2025-02-17）](https://developers.apple.com/news/upcoming-requirements/?id=02172025a)

完成上述步骤后，即满足当前在欧盟 App Store 的 DSA 合规要求；后续若 Apple 或欧盟有更新，以官方说明为准。
