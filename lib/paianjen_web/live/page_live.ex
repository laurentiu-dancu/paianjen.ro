defmodule PaianjenWeb.PageLive do
  use PaianjenWeb, :live_view

  @password "prietenpaianjen"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Acasă",
       password: "",
       error: false,
       authenticated: false
     )}
  end

  @impl true
  def handle_event("check_password", %{"password" => password}, socket) do
    if password == @password do
      {:noreply, push_navigate(socket, to: ~p"/listari")}
    else
      {:noreply, assign(socket, error: true, password: "")}
    end
  end

  @impl true
  def handle_event("update_password", %{"password" => password}, socket) do
    {:noreply, assign(socket, password: password, error: false)}
  end

  @impl true
  def handle_info(:clear_error, socket) do
    {:noreply, assign(socket, error: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-50 via-blue-50 to-indigo-50 flex flex-col items-center justify-center px-4 py-12">
      <%!-- Logo + tagline --%>
      <div class="text-center mb-10">
        <div class="inline-flex items-center justify-center w-16 h-16 bg-indigo-600 rounded-2xl mb-4 shadow-lg">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-8 h-8 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 16v4"/><path d="M12 8v4"/><circle cx="12" cy="12" r="8"/><path d="M8 8c-2 0-3 1-3 3"/><path d="M16 8c2 0 3 1 3 3"/><path d="M8 16c-2 0-3-1-3-3"/><path d="M16 16c2 0 3-1 3-3"/></svg>
        </div>
        <h1 class="text-5xl text-slate-900 tracking-tight mb-2">paianjen.ro</h1>
        <p class="text-slate-500 text-lg">Motorul de căutare pentru apartamente în Cluj County</p>
      </div>

      <%!-- Password card --%>
      <div class="bg-white rounded-2xl shadow-xl p-8 w-full max-w-sm mb-12">
        <p class="text-slate-600 text-center mb-6 text-sm">
          Accesul este rezervat prietenilor paianjen.ro
        </p>
        <form phx-submit="check_password" phx-change="update_password">
          <div class="mb-5">
            <label for="password" class="block text-sm text-slate-700 mb-1.5">Parola</label>
            <input
              type="password"
              id="password"
              name="password"
              value={@password}
              class={"w-full px-4 py-3 border rounded-xl focus:outline-none focus:ring-2 focus:ring-indigo-400 text-slate-900 transition-colors #{if @error, do: "border-red-400 bg-red-50", else: "border-slate-200 bg-slate-50"}"}
              placeholder="Introdu parola"
              autofocus
            />
            <p :if={@error} class="text-red-500 text-xs mt-1.5">
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

      <%!-- How it works --%>
      <div class="w-full max-w-2xl">
        <h2 class="text-center text-xs uppercase tracking-widest text-slate-400 mb-6">
          Cum funcționează
        </h2>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div class="bg-white/70 backdrop-blur rounded-xl p-4 border border-white shadow-sm">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-indigo-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16.5 9.4 7.55 4.24"/><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><polyline points="3.29 7 12 12 20.71 7"/><line x1="12" y1="22" x2="12" y2="12"/></svg>
            <p class="text-sm text-slate-800 mb-1">Grupăm listările</p>
            <p class="text-xs text-slate-500 leading-relaxed">Anunțuri pentru același apartament sunt adunate într-un singur card</p>
          </div>
          <div class="bg-white/70 backdrop-blur rounded-xl p-4 border border-white shadow-sm">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-indigo-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
            <p class="text-sm text-slate-800 mb-1">Timp pe piață</p>
            <p class="text-xs text-slate-500 leading-relaxed">Sortăm după cel mai recent anunț — cele noi apar primele</p>
          </div>
          <div class="bg-white/70 backdrop-blur rounded-xl p-4 border border-white shadow-sm">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-indigo-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0"/><circle cx="12" cy="12" r="3"/></svg>
            <p class="text-sm text-slate-800 mb-1">Comision vizibil</p>
            <p class="text-xs text-slate-500 leading-relaxed">Comisionul agenției apare transparent, în euro, nu ascuns în preț</p>
          </div>
          <div class="bg-white/70 backdrop-blur rounded-xl p-4 border border-white shadow-sm">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-indigo-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><path d="m9 11 3 3L22 4"/></svg>
            <p class="text-sm text-slate-800 mb-1">Sănătate listare</p>
            <p class="text-xs text-slate-500 leading-relaxed">Arătăm câte anunțuri sunt încă active față de total</p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
