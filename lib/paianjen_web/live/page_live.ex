defmodule PaianjenWeb.PageLive do
  use PaianjenWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    if session["authenticated"] do
      {:ok, push_navigate(socket, to: ~p"/listari")}
    else
      {:ok,
       assign(socket,
         page_title: "Acasă"
       )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-50 via-blue-50 to-indigo-50 flex flex-col items-center justify-center px-4 py-12">
      <%!-- Logo + tagline --%>
      <div class="text-center mb-10">
        <div class="inline-flex items-center justify-center w-16 h-16 rounded-2xl mb-4 overflow-hidden">
          <img src={~p"/images/spider.svg"} alt="Paianjen logo" class="w-full h-full" />
        </div>
        <h1 class="text-5xl text-slate-900 tracking-tight mb-2">paianjen.ro</h1>
        <p class="text-slate-500 text-lg">Mic motor de căutare pentru apartamente în Cluj</p>
      </div>

      <%!-- Password card --%>
      <div class="bg-white rounded-2xl shadow-xl p-8 w-full max-w-sm mb-12">
        <p class="text-slate-600 text-center mb-6 text-sm">
          Accesul este rezervat prietenilor paianjen.ro
        </p>
        <form method="post" action="/login">
          <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
          <input type="hidden" name="return_to" value="/listari" />
          <div class="mb-5">
            <label for="password" class="block text-sm text-slate-700 mb-1.5">Parola</label>
            <input
              type="text"
              id="password"
              name="password"
              class={"w-full px-4 py-3 border rounded-xl focus:outline-none focus:ring-2 focus:ring-indigo-400 text-slate-900 transition-colors #{if Phoenix.Flash.get(@flash, :error) != nil, do: "border-red-400 bg-red-50", else: "border-slate-200 bg-slate-50"}"}
              placeholder="Introdu parola"
              autofocus
            />
            <p :if={Phoenix.Flash.get(@flash, :error) != nil} class="text-red-500 text-xs mt-1.5">
              Parolă incorectă — verifică pe social media!
            </p>
          </div>
          <button
            type="submit"
            class="w-full bg-indigo-600 text-white py-3 rounded-xl hover:bg-indigo-700 transition-colors text-sm"
          >
            Intră
          </button>
        </form>
        <p class="text-slate-400 text-xs text-center mt-5">
          Nu ai parola? Urmărește-ne pe social media!
        </p>
      </div>
    </div>
    """
  end
end
