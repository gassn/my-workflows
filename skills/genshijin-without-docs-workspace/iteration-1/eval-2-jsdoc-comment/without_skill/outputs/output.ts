/**
 * 指定されたIDのユーザー情報をAPIから取得する。
 *
 * `/api/users/{id}` エンドポイントに対してフェッチを行い、失敗した場合は
 * 指定された回数までリトライする。すべてのリトライで成功レスポンス（res.ok）が
 * 得られなかった場合は `null` を返す。最後のリトライで例外が発生した場合のみ
 * その例外を再スローする。
 *
 * @param id - 取得対象のユーザーID。URLパスにそのまま埋め込まれる。
 * @param retries - リトライ回数の上限（デフォルト: 3）。ループの総試行回数でもある。
 * @returns 取得に成功した場合は `User` オブジェクト、すべての試行で `res.ok` が
 *          `false` だった場合は `null` を返す Promise。
 * @throws 最後の試行（`i === retries - 1`）で `fetch` が例外をスローした場合、
 *         その例外を再スローする。
 *
 * @example
 * ```ts
 * const user = await fetchUser("123");
 * if (user) {
 *   console.log(user.name);
 * }
 * ```
 */
async function fetchUser(id: string, retries: number = 3): Promise<User | null> {
  for (let i = 0; i < retries; i++) {
    try {
      const res = await fetch(`/api/users/${id}`);
      if (res.ok) return await res.json();
    } catch (e) {
      if (i === retries - 1) throw e;
    }
  }
  return null;
}
