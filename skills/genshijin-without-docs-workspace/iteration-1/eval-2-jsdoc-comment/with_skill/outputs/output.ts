/**
 * 指定されたIDのユーザー情報をAPIから取得します。
 *
 * ネットワークエラーが発生した場合は、指定された回数までリトライを行います。
 * レスポンスが成功ステータス（`res.ok` が真）の場合はJSONとしてパースしたユーザーオブジェクトを返します。
 * すべての試行でレスポンスが成功ステータスを返さなかった場合は `null` を返します。
 * 最後のリトライでも例外が発生した場合は、その例外をそのまま再スローします。
 *
 * @param id - 取得対象のユーザーID。APIエンドポイント `/api/users/:id` のパスパラメータとして使用されます。
 * @param retries - リトライを含む最大試行回数。既定値は `3` です。
 * @returns 取得に成功した場合は `User` オブジェクト、すべての試行で成功ステータスが返らなかった場合は `null` を返すPromise。
 * @throws 最後の試行で `fetch` が例外をスローした場合、その例外をそのまま再スローします。
 *
 * @example
 * ```ts
 * const user = await fetchUser("abc123");
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
