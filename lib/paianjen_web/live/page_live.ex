defmodule PaianjenWeb.PageLive do
  use PaianjenWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Acasă")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <div class="text-center max-w-2xl mx-auto">
        <div class="text-6xl mb-6">🕷️</div>
        <h1 class="text-4xl font-bold tracking-tight text-stone-900 sm:text-5xl">
          paianjen
        </h1>
        <p class="mt-4 text-xl text-stlate-500">
          Mic motor de căutare imobiliară
        </p>
        <p class="mt-2 text-base text-stone-500">
          Găsește anunțuri de la persoane fizice în Cluj-Napoca și județul Cluj.
          Anunțuri noi, fără agenții.
        </p>

        <div class="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
          <.link
            navigate={~p"/listings"}
            class="inline-flex items-center gap-2 rounded-lg bg-amber-500 px-6 py-3 text-base font-semibold text-white shadow-sm hover:bg-amber-600 transition-colors"
          >
            <span>Caută anunțuri</span>
            <span aria-hidden="true">→</span>
          </.link>
        </div>

        <div class="mt-16 grid grid-cols-1 sm:grid-cols-3 gap-8 text-center">
          <div class="rounded-xl bg-white p-6 shadow-sm border border-stone-100">
            <div class="text-3xl mb-3">🏠</div>
            <h3 class="font-semibold text-stone-800">Vânzări directe</h3>
            <p class="mt-1 text-sm text-stone-500">De la persoane fizice, fără intermediari</p>
          </div>
          <div class="rounded-xl bg-white p-6 shadow-sm border border-stone-100">
            <div class="text-3xl mb-3">🕐</div>
            <h3 class="font-semibold text-stone-800">Cele mai noi primele</h3>
            <p class="mt-1 text-sm text-stone-500">Anunțuri fresh, sortate după dată</p>
          </div>
          <div class="rounded-xl bg-white p-6 shadow-sm border border-stone-100">
            <div class="text-3xl mb-3">📍</div>
            <h3 class="font-semibold text-stone-800">Cluj-Napoca</h3>
            <p class="mt-1 text-sm text-stone-500">Focus pe Cluj-Napoca și județul Cluj</p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
