---
layout: default
title: How we use AI
permalink: /ai-use/
description: Where AI is used in building CalCOFI.io, where it is not, and who answers for the result.
---
<div class="cc-container ai-use">
<h1>How we use AI</h1>

<p>CalCOFI.io is built by a small team working with an AI assistant (Claude, by Anthropic). This page says where it is used, where it is not, and who answers for the result.</p>

<h2>Where AI is used</h2>
<ul>
  <li><strong>Code.</strong> Most of the code behind this site, the Explorer, the Query Builder and the pipeline that assembles each database release is written with the assistant and reviewed by the team.</li>
  <li><strong>Words.</strong> It drafts documentation, release notes and some of the text on these pages, such as a dataset's plain name and short description. A drafted description stays a draft until its data provider has reviewed it.</li>
  <li><strong>Checks.</strong> It helps write the tests each release must pass, and helps find and report problems in incoming files.</li>
</ul>

<h2>Where it is not</h2>
<ul>
  <li><strong>No measurement, count or species identification is made, filled in or changed by AI.</strong> Every value comes from the files the data providers publish.</li>
  <li><strong>Every step from a provider's file to a release is code you can read</strong>, in the <a href="https://github.com/CalCOFI/workflows">workflows repository</a>. A derived value, such as mixed-layer depth, is computed by a published method named beside it.</li>
  <li><strong>No chatbot answers for the data.</strong> Charts, maps and downloads are drawn from the release by ordinary code.</li>
</ul>

<h2>Who answers for it</h2>
<p>People do. The CalCOFI.io team decides what is published, and the data providers remain the authority on their data. Changes made with the assistant are marked as co-authored in the public history of each <a href="https://github.com/CalCOFI">CalCOFI repository</a>, and each release lists what changed in its <a href="https://storage.calcofi.io/calcofi-db/ducklake/releases/RELEASES.html">release notes</a>.</p>

<p>If you spot a mistake, write to <a href="mailto:{{ site.contact_email | escape }}">{{ site.contact_email | escape }}</a>.</p>
</div>
