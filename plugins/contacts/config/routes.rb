resources :projects do
  resources :contacts
end

match '/contacts/context_menu', to: 'contact_context_menus#contacts', as: 'contacts_context_menu', via: [:get, :post]
