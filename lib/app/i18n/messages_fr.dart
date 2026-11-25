/// Dictionnaire français (source de vérité UI mobile).
const Map<String, String> messagesFr = {
  // Locale
  'locale.fr': 'Français',
  'locale.wo': 'Wolof',
  'locale.switch': 'Langue',
  'locale.wolofSoon': 'Wolof · brouillon (à relire)',
  // Sous-titre sous les titres d’auth : vide en FR (plus de « Wolof · à traduire »).
  'locale.hint': '',

  // Commun
  'common.back': 'Retour',
  'common.continue': 'Continuer',
  'common.cancel': 'Annuler',
  'common.save': 'Enregistrer',
  'common.swipeSave': 'Glissez pour enregistrer',
  'common.swipeConnect': 'Glissez pour vous connecter',
  'common.swipeCreate': 'Glissez pour créer mon compte',
  'common.busy': 'Patientez…',
  'common.changeRole': 'Changer de rôle',

  // Rôle
  'role.title': 'Mbay Diaay',
  'role.lead': 'Qui êtes-vous ? Une seule application, deux parcours.',
  'role.tech': 'Technicien',
  'role.techSub':
      'Enquêtes terrain, producteurs, parcelles, synchronisation.',
  'role.producer': 'Producteur',
  'role.producerSub':
      'Vos parcelles, calendrier cultural, demande de correction.',
  'role.footer': 'Vous pourrez changer de rôle après déconnexion.',

  // Nouveau / déjà inscrit
  'intent.title': 'Bienvenue',
  'intent.leadTech':
      'Activez votre compte avec le code du gestionnaire, ou reconnectez-vous.',
  'intent.leadProd':
      'Créez votre espace producteur, ou reconnectez-vous avec votre téléphone.',
  'intent.first': 'Je suis nouveau',
  'intent.returning': 'J’ai déjà un compte',
  'intent.firstTechSub':
      'Code à 5 chiffres remis par le gestionnaire, puis votre mot de passe.',
  'intent.returningTechSub':
      'Téléphone et mot de passe choisis à la première connexion.',
  'intent.firstProdSub': 'Inscription avec votre numéro de téléphone.',
  'intent.returningProdSub': 'Connexion avec téléphone et mot de passe.',
  'intent.footer': 'Vous pourrez revenir en arrière pour changer de rôle.',

  // Auth technicien
  'auth.tech.first': 'Première connexion',
  'auth.tech.password': 'Connexion à votre compte',
  'auth.tech.email': 'Compte e-mail (test)',
  'auth.tech.reconnect': 'Reconnexion',
  'auth.tech.seed': 'Accès seed local · Fatou Sarr (PIN 1234)',
  'auth.tech.byPhone': 'Connexion par téléphone',
  'auth.tech.byEmail': 'Compte e-mail (test)',
  'auth.tech.swipeActivate': 'Glissez pour activer',
  'auth.tech.swipeLogin': 'Glissez pour vous connecter',
  'auth.tech.swipeOtp': 'Glissez pour recevoir le code',

  // Auth producteur
  'auth.prod.title': 'Espace producteur',
  'auth.prod.lead':
      'Consultez vos parcelles, votre calendrier, et demandez une correction.',
  'auth.prod.preview': 'Aperçu design (sans compte)',
  'auth.prod.seed': 'Accès seed local · Aïssa Diop (77 000 00 00)',
  'auth.prod.phoneOnly':
      'Connexion par numéro de téléphone — pas d’e-mail.',
  'auth.prod.login': 'Connexion',
  'auth.prod.register': 'Créer mon compte',
  'auth.prod.phone': 'Téléphone',
  'auth.prod.password': 'Mot de passe',
  'auth.prod.hintLogin':
      'Téléphone et mot de passe choisis à l’inscription.',

  // Shell technicien
  'shell.home': 'Accueil',
  'shell.producers': 'Producteurs',
  'shell.map': 'Carte',
  'shell.todo': 'À compléter',
  'shell.profile': 'Profil',

  // Producteurs (liste)
  'producers.title': 'Producteurs',
  'producers.search': 'Nom, village ou téléphone',
  'producers.count': '@count producteurs · SCOOP @scoop',
  'producers.empty': 'Aucun producteur trouvé',
  'producers.emptyHint': 'Vérifiez l\'orthographe ou créez une fiche.',
  'producers.archived': 'Fiches archivées · touchez une fiche pour la restaurer',
  'producers.noneArchived': 'Aucune fiche archivée',
  'producers.noneArchivedHint': 'Les fiches archivées apparaissent ici.',
  'producers.fix': '@count à corriger',
  'producers.backList': 'Retour aux fiches',
  'producers.archivedChip': 'Archivées · @count',
  'producers.chipArchived': 'Archivée',
  'producers.chipNew': 'Nouveau',

  // Accueil
  'home.hello': 'Bonjour',
  'home.offline': 'Hors ligne',
  'home.online': 'Réseau',
  'home.fix': 'éléments à corriger',
  'home.fixHint': 'Touchez pour voir et corriger.',
  'home.newProducer': 'Nouveau producteur',
  'home.survey': 'Relever une parcelle',
  'home.todo': 'À faire',
  'home.search': 'Chercher',
  'home.sale': 'Vente',
  'home.charge': 'Charge',
  'home.recent': 'Vus récemment',
  'home.seeAll': 'Tout voir',
  'home.producersList': 'Liste des producteurs',
  'home.todoList': 'Liste des tâches à effectuer',
  'home.quick': 'Saisies rapides',
  'home.autoSend': 'Envoi automatique en cours de route.',
  'home.registered': 'Producteurs enregistrés',
  'home.yesterday': 'Hier',

  // Shell producteur
  'prod.home.hello': 'Bonjour',
  'prod.home.space': 'Votre espace',
  'prod.home.spaceSub':
      'Ici : vos parcelles, la campagne en cours, et ce que votre SCOOP attend de vous.',
  'prod.home.correction': 'Demander une correction',
  'prod.home.correctionSub': 'Signaler une erreur sur votre fiche',
  'prod.home.stats': 'En un coup d’œil',
  'prod.home.statPlots': 'Parcelles',
  'prod.home.statHa': 'Surface (ha)',
  'prod.home.statCrop': 'Culture principale',
  'prod.home.next': 'Prochaines étapes',
  'prod.home.nextPlot': 'Voir vos parcelles',
  'prod.home.nextPlotSub': 'Surfaces et cultures déclarées',
  'prod.home.nextCal': 'Calendrier cultural',
  'prod.home.nextCalSub': 'Semis, traitements, récolte',
  'prod.home.hint':
      'Les données ci-dessous sont un aperçu. Votre SCOOP les mettra à jour dès que le compte producteur sera branché au serveur.',
  'prod.plots': 'Parcelles',
  'prod.plotsLead': 'Vos terrains recensés avec la coopérative.',
  'prod.plotsEmpty':
      'Aucune parcelle pour l’instant. Après le passage du technicien, elles apparaîtront ici avec la surface et la culture.',
  'prod.plot.measured': 'Mesurée',
  'prod.plot.declared': 'Déclarée',
  'prod.calendar': 'Calendrier',
  'prod.calendarLead': 'Repères de la campagne en cours.',
  'prod.calendarEmpty':
      'Pas encore d’opérations planifiées. Elles arriveront avec le plan cultural de votre SCOOP.',
  'prod.cal.done': 'Fait',
  'prod.cal.soon': 'À venir',
  'prod.cal.now': 'En cours',
  'prod.profile': 'Profil',
  'prod.role': 'Rôle · producteur',
  'prod.profile.phone': 'Téléphone',
  'prod.profile.scoop': 'Coopérative',
  'prod.profile.help':
      'Pour changer une info sur votre fiche, utilisez « Demander une correction » depuis l’accueil.',
  'prod.logout': 'Glissez pour vous déconnecter',

  // PIN
  'pin.choose': 'Choisissez un code PIN',
  'pin.confirm': 'Confirmez le code PIN',
  'pin.current': 'Entrez votre code PIN actuel',
  'pin.wrong': 'Code PIN incorrect',
  'pin.changed': 'Code PIN modifié.',
  'pin.mismatch': 'Les deux codes ne correspondent pas.',

  // Profil
  'profile.language': 'Langue',
  'profile.languageSub': '@current',
  'profile.pin': 'Changer mon code PIN',
  'profile.network': 'Réseau (simulation)',
  'profile.networkOn': 'Connecté · touchez pour couper',
  'profile.networkOff': 'Coupé · touchez pour rétablir',
  'profile.producerPreview': 'Compte seed producteur',
  'profile.producerPreviewSub': 'Aïssa Diop · retour possible',
  'profile.changeRole': 'Changer de rôle',
  'profile.changeRoleSub': 'Technicien ou producteur au démarrage',

  // Offline / sync
  'offline.banner': 'Hors ligne · données locales',
  'offline.network': 'Hors ligne',
  'offline.networkOn': 'Réseau',
  'offline.toastOff': 'Mode hors ligne · aucune requête serveur',
  'offline.toastOn': 'Réseau rétabli',
  'sync.pending': 'En attente d\'envoi',

  // Cultures
  'crops.save': 'Glissez pour enregistrer',
};
